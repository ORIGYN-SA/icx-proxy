use crate::canister::resolve_canister_id_from_uri;
use crate::canister::PhoneBookCanisterParam;
use crate::canister::{RealAccess, RedisParam};
use async_recursion::async_recursion;
use clap::{crate_authors, crate_version, Parser};
use flate2::read::{DeflateDecoder, GzDecoder};
use hyper::http::request::Parts;

use hyper::{
    body,
    body::Bytes,
    service::{make_service_fn, service_fn},
    Body, Request, Response, Server, StatusCode, Uri,
};
use ic_agent::{
    agent::http_transport::ReqwestHttpReplicaV2Transport,
    export::Principal,
    ic_types::{hash_tree::LookupResult, HashTree},
    lookup_value, Agent, AgentError, Certificate,
};
use ic_utils::{
    call::AsyncCall,
    call::SyncCall,
    interfaces::http_request::{
        HeaderField, HttpRequestCanister, HttpRequestStreamingCallbackAny, HttpResponse,
        StreamingCallbackHttpResponse, StreamingStrategy, Token,
    },
};
use lazy_regex::regex_captures;
use redis::Commands;
use sha2::{Digest, Sha256};
use slog::Drain;
use std::{
    convert::Infallible,
    error::Error,
    io::Read,
    net::SocketAddr,
    path::PathBuf,
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc, Mutex,
    },
};
use tokio::sync::mpsc;

mod canister;
//mod config;
mod logging;

type HttpResponseAny = HttpResponse<Token, HttpRequestStreamingCallbackAny>;

// Limit the total number of calls to an HTTP Request loop to 1000 for now.
const MAX_HTTP_REQUEST_STREAM_CALLBACK_CALL_COUNT: i32 = 1000;
//set str because clap need str for default value.
const DEFAULT_REDIS_EXPIRY_CACHE_TIMEOUT_IN_SECOND: &'static str = "86400"; //24h = 3600 * 24

// The maximum length of a body we should log as tracing.
const MAX_LOG_BODY_SIZE: usize = 100;
const MAX_LOG_CERT_NAME_SIZE: usize = 100;
const MAX_LOG_CERT_B64_SIZE: usize = 2000;

// The limit of a buffer we should decompress ~10mb.
const MAX_CHUNK_SIZE_TO_DECOMPRESS: usize = 1024;
const MAX_CHUNKS_TO_DECOMPRESS: u64 = 10_240;

#[derive(Parser)]
#[clap(
    version = crate_version!(),
    author = crate_authors!(),
    propagate_version = true,
)]
pub(crate) struct Opts {
    /// Verbose level. By default, INFO will be used. Add a single `-v` to upgrade to
    /// DEBUG, and another `-v` to upgrade to TRACE.
    #[clap(long, short('v'), parse(from_occurrences))]
    verbose: u64,

    /// Quiet level. The opposite of verbose. A single `-q` will drop the logging to
    /// WARN only, then another one to ERR, and finally another one for FATAL. Another
    /// `-q` will silence ALL logs.
    #[clap(long, short('q'), parse(from_occurrences))]
    quiet: u64,

    /// Mode to use the logging. "stderr" will output logs in STDERR, "file" will output
    /// logs in a file, and "tee" will do both.
    #[clap(long("log"), default_value("stderr"), possible_values(&["stderr", "tee", "file"]))]
    logmode: String,

    /// File to output the log to, when using logmode=tee or logmode=file.
    #[clap(long)]
    logfile: Option<PathBuf>,

    /// The address to bind to.
    #[clap(long, default_value = "127.0.0.1:3000")]
    address: SocketAddr,

    /// A replica to use as backend. Locally, this should be a local instance or the
    /// boundary node. Multiple replicas can be passed and they'll be used round-robin.
    #[clap(long, default_value = "http://localhost:8000/")]
    replica: Vec<String>,

    /// Whether or not this is run in a debug context (e.g. errors returned in responses
    /// should show full stack and error details).
    #[clap(long)]
    debug: bool,

    /// Whether or not to fetch the root key from the replica back end. Do not use this when
    /// talking to the Internet Computer blockchain mainnet as it is unsecure.
    #[clap(long)]
    fetch_root_key: bool,

    /// A map of domain names to canister IDs.
    /// Format: domain.name:canister-id
    #[clap(long, short('r'))]
    redis_url: String,

    /// A map of domain names to canister IDs.
    /// Format: domain.name:canister-id
    #[clap(long, short('p'))]
    phonebook_id: String,

    /// The address to bind to.
    #[clap(long, default_value = DEFAULT_REDIS_EXPIRY_CACHE_TIMEOUT_IN_SECOND)]
    redis_cache_timeout: usize,
}

fn decode_hash_tree(
    name: &str,
    value: Option<String>,
    logger: &slog::Logger,
) -> Result<Vec<u8>, ()> {
    match value {
        Some(tree) => base64::decode(tree).map_err(|e| {
            slog::warn!(logger, "Unable to decode {} from base64: {}", name, e);
        }),
        _ => Err(()),
    }
}

struct HeadersData {
    certificate: Option<Result<Vec<u8>, ()>>,
    tree: Option<Result<Vec<u8>, ()>>,
    encoding: Option<String>,
}

fn extract_headers_data(headers: &[HeaderField], logger: &slog::Logger) -> HeadersData {
    let mut headers_data = HeadersData {
        certificate: None,
        tree: None,
        encoding: None,
    };

    for HeaderField(name, value) in headers {
        if name.eq_ignore_ascii_case("IC-CERTIFICATE") {
            for field in value.split(',') {
                if let Some((_, name, b64_value)) = regex_captures!("^(.*)=:(.*):$", field.trim()) {
                    slog::trace!(
                        logger,
                        ">> certificate {:.l1$}: {:.l2$}",
                        name,
                        b64_value,
                        l1 = MAX_LOG_CERT_NAME_SIZE,
                        l2 = MAX_LOG_CERT_B64_SIZE
                    );
                    let bytes = decode_hash_tree(name, Some(b64_value.to_string()), logger);
                    if name == "certificate" {
                        headers_data.certificate = Some(match (headers_data.certificate, bytes) {
                            (None, bytes) => bytes,
                            (Some(Ok(certificate)), Ok(bytes)) => {
                                slog::warn!(logger, "duplicate certificate field: {:?}", bytes);
                                Ok(certificate)
                            }
                            (Some(Ok(certificate)), Err(_)) => {
                                slog::warn!(
                                    logger,
                                    "duplicate certificate field (failed to decode)"
                                );
                                Ok(certificate)
                            }
                            (Some(Err(_)), bytes) => {
                                slog::warn!(
                                    logger,
                                    "duplicate certificate field (failed to decode)"
                                );
                                bytes
                            }
                        });
                    } else if name == "tree" {
                        headers_data.tree = Some(match (headers_data.tree, bytes) {
                            (None, bytes) => bytes,
                            (Some(Ok(tree)), Ok(bytes)) => {
                                slog::warn!(logger, "duplicate tree field: {:?}", bytes);
                                Ok(tree)
                            }
                            (Some(Ok(tree)), Err(_)) => {
                                slog::warn!(logger, "duplicate tree field (failed to decode)");
                                Ok(tree)
                            }
                            (Some(Err(_)), bytes) => {
                                slog::warn!(logger, "duplicate tree field (failed to decode)");
                                bytes
                            }
                        });
                    }
                }
            }
        } else if name.eq_ignore_ascii_case("CONTENT-ENCODING") {
            let enc = value.trim().to_string();
            headers_data.encoding = Some(enc);
        }
    }

    headers_data
}

enum ForwardRequestResponse {
    RedirectUrl(String),
    Response(Result<Response<Body>, anyhow::Error>),
}

// #[derive(Clone)]
struct ForwardRequestParams {
    body: Vec<u8>,
    parts: Parts,
}

//From Request to ForwardRequestParams
async fn extract_forward_request_params<'a>(
    request: Request<Body>,
) -> Result<ForwardRequestParams, anyhow::Error> {
    let (parts, body) = request.into_parts();

    let body = body::to_bytes(body).await?.to_vec();
    Ok(ForwardRequestParams { body, parts })
}

async fn forward_request(
    request: ForwardRequestParams,
    agent: Arc<Agent>,
    _redis_param: Option<&RedisParam>,
    _phonebook_param: Option<&PhoneBookCanisterParam>,
    logger: slog::Logger,
    canister_params: TargetCanisterParams,
) -> Result<ForwardRequestResponse, anyhow::Error> {
    let ForwardRequestParams { body, parts } = request;
    let TargetCanisterParams {
        canister_id,
        found_uri,
    } = canister_params;

    slog::trace!(
        logger,
        "<< {} {} {:?} resolved to {}/-/{}",
        &parts.method,
        &parts.uri,
        &parts.version,
        canister_id,
        found_uri,
    );
    let skip_validation = skip_validation(&parts.uri);
    let method = parts.method;
    let headers = parts
        .headers
        .iter()
        .filter_map(|(name, value)| {
            Some(HeaderField(
                name.as_str().into(),
                value.to_str().ok()?.into(),
            ))
        })
        .inspect(|HeaderField(name, value)| {
            slog::trace!(logger, "<< {}: {}", name, value);
        })
        .collect::<Vec<_>>();

    slog::trace!(logger, "<<");
    if logger.is_trace_enabled() {
        let body = String::from_utf8_lossy(&body[0..usize::min(body.len(), MAX_LOG_BODY_SIZE)]);
        slog::trace!(
            logger,
            "<< \"{}\"{}",
            &body.escape_default(),
            if body.len() > MAX_LOG_BODY_SIZE {
                format!("... {} bytes total", body.len())
            } else {
                String::new()
            }
        );
    }

    let canister = HttpRequestCanister::create(agent.as_ref(), canister_id);
    let query_result = canister
        .http_request_custom(
            method.as_str(),
            found_uri.as_str(),
            headers.iter().cloned(),
            &body,
        )
        .call()
        .await;

    fn handle_result(
        result: Result<(HttpResponseAny,), AgentError>,
    ) -> Result<HttpResponseAny, Result<Response<Body>, anyhow::Error>> {
        // If the result is a Replica error, returns the 500 code and message. There is no information
        // leak here because a user could use `dfx` to get the same reply.
        match result {
            Ok((http_response,)) => Ok(http_response),
            Err(AgentError::ReplicaError {
                reject_code,
                reject_message,
            }) => Err(Ok(Response::builder()
                .status(StatusCode::INTERNAL_SERVER_ERROR)
                .body(format!(r#"Replica Error ({}): "{}""#, reject_code, reject_message).into())
                .unwrap())),
            Err(e) => Err(Err(e.into())), // <-- PLACE TO HANDLE 307 REDIRECT WITH RECURSION>
        }
    }

    type QueryResponse = HttpResponse<Token, HttpRequestStreamingCallbackAny>;

    fn is_redirect(query_response: &QueryResponse) -> Option<String> {
        if query_response.status_code == StatusCode::TEMPORARY_REDIRECT {
            let query_response_headers = query_response.headers.iter().collect::<Vec<_>>();
            let query_response_headers_slice = query_response_headers.as_slice();

            match query_response_headers_slice {
                [HeaderField(name, value)] if name == "Location" => Some(value.to_string()),
                _ => None,
            }
        } else {
            None
        }
    }

    let http_response = match handle_result(query_result) {
        Ok(http_response) => http_response,
        Err(response_or_error) => return Ok(ForwardRequestResponse::Response(response_or_error)),
    };

    if let Some(redirect_url) = is_redirect(&http_response) {
        slog::trace!(logger, ">> 307 Redirect to {}", redirect_url);
        return Ok(ForwardRequestResponse::RedirectUrl(redirect_url));
    }

    let http_response = if http_response.upgrade == Some(true) {
        let waiter = garcon::Delay::builder()
            .throttle(std::time::Duration::from_millis(500))
            .timeout(std::time::Duration::from_secs(15))
            .build();
        let update_result = canister
            .http_request_update_custom(
                method.as_str(),
                found_uri.as_str(),
                headers.iter().cloned(),
                &body,
            )
            .call_and_wait(waiter)
            .await;
        let http_response = match handle_result(update_result) {
            Ok(http_response) => http_response,
            Err(response_or_error) => {
                return Ok(ForwardRequestResponse::Response(response_or_error))
            }
        };
        http_response
    } else {
        http_response
    };

    let mut builder = Response::builder().status(StatusCode::from_u16(http_response.status_code)?);
    for HeaderField(name, value) in &http_response.headers {
        builder = builder.header(name.as_ref(), value.as_ref());
    }

    let headers_data = extract_headers_data(&http_response.headers, &logger);
    let body = if logger.is_trace_enabled() {
        Some(http_response.body.clone())
    } else {
        None
    };

    let is_streaming = http_response.streaming_strategy.is_some();
    let response = if let Some(streaming_strategy) = http_response.streaming_strategy {
        let (mut sender, body) = body::Body::channel();
        let agent = agent.as_ref().clone();
        sender.send_data(Bytes::from(http_response.body)).await?;

        match streaming_strategy {
            StreamingStrategy::Callback(callback) => {
                let streaming_canister_id = callback.callback.0.principal;
                let method_name = callback.callback.0.method;
                let mut callback_token = callback.token;
                let logger = logger.clone();
                tokio::spawn(async move {
                    let canister = HttpRequestCanister::create(&agent, streaming_canister_id);
                    // We have not yet called http_request_stream_callback.
                    let mut count = 0;
                    loop {
                        count += 1;
                        if count > MAX_HTTP_REQUEST_STREAM_CALLBACK_CALL_COUNT {
                            sender.abort();
                            break;
                        }

                        match canister
                            .http_request_stream_callback(&method_name, callback_token)
                            .call()
                            .await
                        {
                            Ok((StreamingCallbackHttpResponse { body, token },)) => {
                                if sender.send_data(Bytes::from(body)).await.is_err() {
                                    sender.abort();
                                    break;
                                }
                                if let Some(next_token) = token {
                                    callback_token = next_token;
                                } else {
                                    break;
                                }
                            }
                            Err(e) => {
                                slog::debug!(logger, "Error happened during streaming: {}", e);
                                sender.abort();
                                break;
                            }
                        }
                    }
                });
            }
        }

        builder.body(body)?
    } else {
        if !skip_validation {
            let body_valid = validate(
                &headers_data,
                &canister_id,
                &agent,
                &parts.uri,
                &http_response.body,
                logger.clone(),
            );
            if body_valid.is_err() {
                return Ok(ForwardRequestResponse::Response(Ok(Response::builder()
                    .status(StatusCode::INTERNAL_SERVER_ERROR)
                    .body(body_valid.unwrap_err().into())
                    .unwrap())));
            }
        }
        builder.body(http_response.body.into())?
    };

    if logger.is_trace_enabled() {
        slog::trace!(
            logger,
            ">> {:?} {} {}",
            &response.version(),
            response.status().as_u16(),
            response.status().to_string()
        );

        for (name, value) in response.headers() {
            let value = String::from_utf8_lossy(value.as_bytes());
            slog::trace!(logger, ">> {}: {}", name, value);
        }

        let body = body.unwrap_or_else(|| b"... streaming ...".to_vec());

        slog::trace!(logger, ">>");
        slog::trace!(
            logger,
            ">> \"{}\"{}",
            String::from_utf8_lossy(&body[..usize::min(MAX_LOG_BODY_SIZE, body.len())])
                .escape_default(),
            if is_streaming {
                "... streaming".to_string()
            } else if body.len() > MAX_LOG_BODY_SIZE {
                format!("... {} bytes total", body.len())
            } else {
                String::new()
            }
        );
    }

    Ok(ForwardRequestResponse::Response(Ok(response)))
}

fn skip_validation(url: &hyper::Uri) -> bool {
    url.query()
        .map(|query| if query.contains("_raw") { true } else { false })
        .unwrap_or(false)
}

fn validate(
    headers_data: &HeadersData,
    canister_id: &Principal,
    agent: &Agent,
    uri: &Uri,
    response_body: &[u8],
    logger: slog::Logger,
) -> Result<(), String> {
    let body_sha = if let Some(body_sha) =
        decode_body_to_sha256(response_body, headers_data.encoding.clone())
    {
        body_sha
    } else {
        return Err("Body could not be decoded".into());
    };

    let body_valid = match (
        headers_data.certificate.as_ref(),
        headers_data.tree.as_ref(),
    ) {
        (Some(Ok(certificate)), Some(Ok(tree))) => match validate_body(
            Certificates { certificate, tree },
            canister_id,
            agent,
            uri,
            &body_sha,
            logger.clone(),
        ) {
            Ok(true) => Ok(()),
            Ok(false) => Err("Body does not pass verification".to_string()),
            Err(e) => Err(format!("Certificate validation failed: {}", e)),
        },
        (Some(_), _) | (_, Some(_)) => Err("Body does not pass verification".to_string()),

        // TODO: Remove this (FOLLOW-483)
        // Canisters don't have to provide certified variables
        // This should change in the future, grandfathering in current implementations
        (None, None) => Ok(()),
    };

    if body_valid.is_err() && !cfg!(feature = "skip_body_verification") {
        return body_valid;
    }

    Ok(())
}

fn decode_body_to_sha256(body: &[u8], encoding: Option<String>) -> Option<[u8; 32]> {
    let mut sha256 = Sha256::new();
    let mut decoded = [0u8; MAX_CHUNK_SIZE_TO_DECOMPRESS];
    match encoding.as_deref() {
        Some("gzip") => {
            let mut decoder = GzDecoder::new(body);
            for _ in 0..MAX_CHUNKS_TO_DECOMPRESS {
                let bytes = decoder.read(&mut decoded).ok()?;
                if bytes == 0 {
                    return Some(sha256.finalize().into());
                }
                sha256.update(&decoded[0..bytes]);
            }
            if decoder.bytes().next().is_some() {
                return None;
            }
        }
        Some("deflate") => {
            let mut decoder = DeflateDecoder::new(body);
            for _ in 0..MAX_CHUNKS_TO_DECOMPRESS {
                let bytes = decoder.read(&mut decoded).ok()?;
                if bytes == 0 {
                    return Some(sha256.finalize().into());
                }
                sha256.update(&decoded[0..bytes]);
            }
            if decoder.bytes().next().is_some() {
                return None;
            }
        }
        _ => sha256.update(body),
    };
    Some(sha256.finalize().into())
}

struct Certificates<'a> {
    certificate: &'a Vec<u8>,
    tree: &'a Vec<u8>,
}

fn validate_body(
    certificates: Certificates,
    canister_id: &Principal,
    agent: &Agent,
    uri: &Uri,
    body_sha: &[u8; 32],
    logger: slog::Logger,
) -> anyhow::Result<bool> {
    let cert: Certificate =
        serde_cbor::from_slice(certificates.certificate).map_err(AgentError::InvalidCborData)?;
    let tree: HashTree =
        serde_cbor::from_slice(certificates.tree).map_err(AgentError::InvalidCborData)?;

    if let Err(e) = agent.verify(&cert, *canister_id, false) {
        slog::trace!(logger, ">> certificate failed verification: {}", e);
        return Ok(false);
    }

    let certified_data_path = vec![
        "canister".into(),
        canister_id.into(),
        "certified_data".into(),
    ];
    let witness = match lookup_value(&cert, certified_data_path) {
        Ok(witness) => witness,
        Err(e) => {
            slog::trace!(
                logger,
                ">> Could not find certified data for this canister in the certificate: {}",
                e
            );
            return Ok(false);
        }
    };
    let digest = tree.digest();

    if witness != digest {
        slog::trace!(
            logger,
            ">> witness ({}) did not match digest ({})",
            hex::encode(witness),
            hex::encode(digest)
        );

        return Ok(false);
    }

    let path = ["http_assets".into(), uri.path().into()];
    let tree_sha = match tree.lookup_path(&path) {
        LookupResult::Found(v) => v,
        _ => match tree.lookup_path(&["http_assets".into(), "/index.html".into()]) {
            LookupResult::Found(v) => v,
            _ => {
                slog::trace!(
                    logger,
                    ">> Invalid Tree in the header. Does not contain path {:?}",
                    path
                );
                return Ok(false);
            }
        },
    };

    Ok(body_sha == tree_sha)
}

fn ok() -> Result<Response<Body>, anyhow::Error> {
    Ok(Response::builder()
        .status(StatusCode::OK)
        .body("OK".into())?)
}

fn unable_to_fetch_root_key() -> Result<Response<Body>, anyhow::Error> {
    Ok(Response::builder()
        .status(StatusCode::INTERNAL_SERVER_ERROR)
        .body("Unable to fetch root key".into())?)
}

#[derive(Clone, Debug)]
pub struct TargetCanisterParams {
    canister_id: Principal,
    found_uri: String,
}

// fn clone_request(request: &Request<Body>) -> impl FnOnce(String) -> Request<Body> {
//     let (parts, body) = request.into_parts();
//     // let method = request.method().clone();
//     // let headers = request.headers().clone();

//     // let body = request.body().concat

//     |new_url| {
//         let new_request = Request::from_parts(Parts {
//             uri: new_url.parse().unwrap(),
//             ..parts
//         }, body);
//         new_request
//     }
// }

#[async_recursion]
#[allow(clippy::too_many_arguments)]
async fn handle_request(
    request: Request<Body>,
    replica_url: String,
    redis_param: Arc<Option<RedisParam>>,
    phonebook_param: Option<PhoneBookCanisterParam>,
    logger: slog::Logger,
    fetch_root_key: bool,
    debug: bool,
) -> Result<Response<Body>, Infallible> {
    // let redirect_request = clone_request(&request);
    let forward_request_params = match extract_forward_request_params(request).await {
        Ok(params) => params,
        Err(e) => {
            slog::error!(logger, ">> Failed to extract forward request params: {}", e);
            return Ok(Response::builder()
                .status(StatusCode::INTERNAL_SERVER_ERROR)
                .body("Failed to extract forward request params".into())
                .unwrap());
        }
    };

    let ForwardRequestParams { body,  parts } = forward_request_params;
    let request_uri = &parts.uri;
    slog::trace!(logger, "handle_request.request_uri:{}", &request_uri);
    let result = if request_uri.path().starts_with("/healthcheck") {
        ok()
    } else {
        let agent = Arc::new(
            ic_agent::Agent::builder()
                .with_transport(ReqwestHttpReplicaV2Transport::create(replica_url.clone()).unwrap())
                .build()
                .expect("Could not create agent..."),
        );
        if fetch_root_key && agent.fetch_root_key().await.is_err() {
            unable_to_fetch_root_key()
        } else {
            let (canister_id, found_uri) = match resolve_canister_id_from_uri(
                &request_uri,
                redis_param.as_ref().as_ref(),
                phonebook_param.as_ref(),
                RealAccess,
                &logger,
            )
            .await
            {
                None => {
                    return Ok(Response::builder()
                        .status(StatusCode::BAD_REQUEST)
                        .body("Could not find a canister id to forward to.".into())
                        .unwrap())
                }
                Some((x, y)) => (x, y),
            };
            let headers = parts.headers.clone();
            let method = parts.method.clone();
            let uri = parts.uri.clone();
            let version = parts.version.clone();

            let mut nr = Request::builder()
                .method(method)
                .uri(uri)
                .version(version)
                // .headers(headers)
                .body(())
                .unwrap();
            nr.headers_mut().extend(headers);

            let result = forward_request(
                ForwardRequestParams {
                    body: body.clone(),
                    parts: nr.into_parts().0,
                },
                agent,
                redis_param.as_ref().as_ref(),
                phonebook_param.as_ref(),
                logger.clone(),
                TargetCanisterParams {
                    canister_id,
                    found_uri,
                },
            )
            .await;

            match result {
                Ok(ForwardRequestResponse::RedirectUrl(redirect_url)) => {
                    let mut nr = Request::builder()
                        .method(parts.method)
                        .uri(redirect_url)
                        .version(parts.version)
                        // .headers(headers)
                        .body(Body::from(body))
                        .unwrap();
                    
                    nr.headers_mut().extend(parts.headers);

                    let response = handle_request(
                        nr,
                        replica_url,
                        redis_param,
                        phonebook_param,
                        logger.clone(),
                        fetch_root_key,
                        debug,
                    )
                    .await;

                    match response {
                        Ok(response) => Ok(response),
                        _ => Ok(Response::builder()
                            .status(StatusCode::INTERNAL_SERVER_ERROR)
                            .body("Error forwarding request".into())
                            .unwrap()),
                    }
                }

                Ok(ForwardRequestResponse::Response(response)) => response,

                Err(e) => {
                    slog::error!(logger, ">> Error forwarding request: {}", e);
                    return Ok(Response::builder()
                        .status(StatusCode::INTERNAL_SERVER_ERROR)
                        .body("Error forwarding request".into())
                        .unwrap());
                }
            }
        }
    };

    match result {
        Err(err) => {
            slog::warn!(logger, "Internal Error during request:\n{:#?}", err);

            Ok(Response::builder()
                .status(StatusCode::INTERNAL_SERVER_ERROR)
                .body(if debug {
                    format!("Internal Error: {:?}", err).into()
                } else {
                    "Internal Server Error".into()
                })
                .unwrap())
        }
        Ok(x) => Ok::<_, Infallible>(x),
    }
}

async fn update_redis_thread(
    redis_url: &str,
    mut redis_rx: mpsc::Receiver<(String, String)>,
    redis_cache_timout: usize,
    logger: slog::Logger,
) -> Result<(), Box<dyn Error>> {
    let redis_client = redis::Client::open(redis_url)?;

    while let Some((alias, canister_id)) = redis_rx.recv().await {
        slog::info!(
            logger,
            "Update Redis with alias:canister {}:{}",
            alias,
            canister_id,
        );
        if let Err(err) = redis_client
            .get_connection()
            .and_then(|mut con| con.set_ex::<_, _, ()>(&alias, &canister_id, redis_cache_timout))
        {
            slog::error!(logger, "Error during Redis cache update: {}", err);
        }
    }
    Ok(())
}

fn main() -> Result<(), Box<dyn Error>> {
    let opts: Opts = Opts::parse();

    let logger = logging::setup_logging(&opts);

    // Prepare a list of agents for each backend replicas.
    let replicas = Mutex::new(opts.replica.clone());

    let counter = AtomicUsize::new(0);
    let debug = opts.debug;
    let fetch_root_key = opts.fetch_root_key;

    //create Redis cache update channel.
    //A cache entry is send to the channel and
    // a async thread read it and send to Redis.
    let (redis_tx, redis_rx) = mpsc::channel(32);
    let redis_logger = logger.clone();
    let th_redis_url = opts.redis_url.clone();
    let th_redis_cache_timeout = opts.redis_cache_timeout;

    //start tokio runtime
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(10)
        .enable_all()
        .build()?;

    //create name alias resolution struct
    let redis_param: Option<RedisParam> = runtime.block_on(async {
        RedisParam::try_new(Some(&opts.redis_url), Some(redis_tx), &logger).await
    });
    let redis_param = Arc::new(redis_param);

    let service = make_service_fn(|_| {
        let redis_param = redis_param.clone();
        let logger = logger.clone();

        // Select an agent.
        let replica_url_array = replicas.lock().unwrap();
        let count = counter.fetch_add(1, Ordering::SeqCst);
        let replica_url = replica_url_array
            .get(count % replica_url_array.len())
            .unwrap_or_else(|| unreachable!());
        let replica_url = replica_url.clone();
        slog::debug!(logger, "make service Replica URL: {}", replica_url);

        let phone_book_id = opts.phonebook_id.clone();

        async move {
            Ok::<_, Infallible>(service_fn(move |req| {
                let logger = logger.clone();
                let redis_param = redis_param.clone();
                //update phone book canister call with network replica
                let phonebook_param =
                    PhoneBookCanisterParam::new(&phone_book_id, &replica_url, &logger).ok();

                handle_request(
                    req,
                    replica_url.clone(),
                    redis_param,
                    phonebook_param,
                    logger,
                    fetch_root_key,
                    debug,
                )
            }))
        }
    });

    slog::info!(
        logger,
        "Starting server. Listening on http://{}/",
        opts.address
    );

    runtime.spawn(async move {
        if let Err(err) = update_redis_thread(
            &th_redis_url,
            redis_rx,
            th_redis_cache_timeout,
            redis_logger.clone(),
        )
        .await
        {
            slog::error!(
                redis_logger,
                "Error Bad Redis Url can't start client connection: {} for url:{}",
                err,
                &th_redis_url
            );
        }
    });
    runtime.block_on(async {
        let server = Server::bind(&opts.address).serve(service);
        server.await?;
        Ok(())
    })
}
