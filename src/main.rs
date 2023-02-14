use crate::canister::resolve_canister_id_from_uri;
use crate::canister::PhoneBookCanisterParam;
use crate::canister::{RealAccess, RedisParam};
use clap::{crate_authors, crate_version, Parser};
use hyper::{
    body,
    body::Bytes,
    service::{make_service_fn, service_fn},
    Body, Request, Response, Server, StatusCode,
};
use ic_agent::{
    agent::http_transport::ReqwestHttpReplicaV2Transport,
    export::Principal,
    Agent, AgentError,
};
use ic_utils::{
    call::AsyncCall,
    call::SyncCall,
    interfaces::http_request::{
        HeaderField, HttpRequestCanister, HttpRequestStreamingCallbackAny, HttpResponse,
        StreamingCallbackHttpResponse, StreamingStrategy, Token,
    },
};
use redis::Commands;
use slog::Drain;
use std::{
    convert::Infallible,
    error::Error,
    net::SocketAddr,
    path::PathBuf,
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc, Mutex,
    },
};
use tokio::sync::mpsc;

use crate::ic_req_headers::HeadersData;
use crate::ic_req_headers::DataExtractor;

mod canister;
//mod config;
mod logging;
mod ic_req_headers;
mod req_validation;

// The maximum length of a body we should log as tracing.
const MAX_LOG_BODY_SIZE: usize = 100;
type HttpResponseAny = HttpResponse<Token, HttpRequestStreamingCallbackAny>;

// Limit the total number of calls to an HTTP Request loop to 1000 for now.
const MAX_HTTP_REQUEST_STREAM_CALLBACK_CALL_COUNT: i32 = 1000;
//set str because clap need str for default value.
const DEFAULT_REDIS_EXPIRY_CACHE_TIMEOUT_IN_SECOND: &'static str = "86400"; //24h = 3600 * 24

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

async fn forward_request(
    request: Request<Body>,
    agent: Arc<Agent>,
    redis_param: Option<&RedisParam>,
    phonebook_param: Option<&PhoneBookCanisterParam>,
    logger: slog::Logger,
    canister_params: TargetCanisterParams,
) -> Result<Response<Body>, Box<dyn Error>> {
    let ( canister_id, found_uri ) = match canister_params.clone() {
        TargetCanisterParams { canister_id, found_uri } => (canister_id, found_uri)
    };
    let request_uri = request.uri();

    slog::trace!(
        logger,
        "<< {} {} {:?} resolved to {}/-/{}",
        request.method(),
        request.uri(),
        &request.version(),
        canister_id,
        found_uri,
    );
    let skip_validation = skip_validation(&request_uri);

    let (parts, body) = request.into_parts();

    let method = parts.method.clone();
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

    let entire_body = body::to_bytes(body).await?.to_vec();

    slog::trace!(logger, "<<");
    if logger.is_trace_enabled() {
        let body = String::from_utf8_lossy(
            &entire_body[0..usize::min(entire_body.len(), MAX_LOG_BODY_SIZE)],
        );
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
            &entire_body,
        )
        .call()
        .await;

    fn handle_result(
        result: Result<(HttpResponseAny,), AgentError>,
    ) -> Result<HttpResponseAny, Result<Response<Body>, Box<dyn Error>>> {
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

    let http_response = match handle_result(query_result) {
        Ok(http_response) => http_response,
        Err(response_or_error) => return response_or_error,
    };

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
                &entire_body,
            )
            .call_and_wait(waiter)
            .await;
        let http_response = match handle_result(update_result) {
            Ok(http_response) => http_response,
            Err(response_or_error) => return response_or_error,
        };
        http_response
    } else {
        http_response
    };

    let mut builder = Response::builder().status(StatusCode::from_u16(http_response.status_code)?);
    for HeaderField(name, value) in &http_response.headers {
        builder = builder.header(name.as_ref(), value.as_ref());
    }

    let headers_data: HeadersData = HeadersData::extract(&http_response.headers, &logger);
    let body = if logger.is_trace_enabled() {
        Some(http_response.body.clone())
    } else {
        None
    };

    let is_streaming = http_response.streaming_strategy.is_some();
    if is_streaming.clone() {
        slog::info!(
            logger,
            "==[ STREAMING ]==> CONTENT DETECTED: {:?}",
            is_streaming.clone(),
        );
    }
    let response = if let Some(streaming_strategy) = http_response.streaming_strategy {
        let (mut sender, body) = body::Body::channel();
        let agent = agent.as_ref().clone();
        sender.send_data(Bytes::from(http_response.body.clone())).await?;

        if !skip_validation {
            //verification first chunk
            let body_valid = req_validation::validate(
                &headers_data,
                &canister_id,
                &agent,
                &parts.uri,
                &http_response.body.clone(),
                logger.clone(),
            );
            if body_valid.is_err() {
                return Ok(Response::builder()
                    .status(StatusCode::INTERNAL_SERVER_ERROR)
                    .body(body_valid.unwrap_err().into())
                    .unwrap());
            }
        }

        slog::info!(
            logger,
            "==[ STREAMING ]==> FIRST CHUNK: {:?}",
            http_response.headers.clone(),
        );

        match streaming_strategy {
            StreamingStrategy::Callback(callback) => {
                // let { principal, method } = callback.callback.0;
                slog::info!(
                    logger,
                    "==[ STREAMING ]==> StreamingStrategy::CALLBACK: {:?}",
                    callback.clone(),
                );
        
                let streaming_canister_id = callback.callback.0.principal;
                let method_name = callback.callback.0.method;
                let mut callback_token = callback.token;
                let logger = logger.clone();
                let uri = parts.uri.clone();

                slog::info!(
                    logger,
                    "==[ STREAMING ]==> PROCESSING CHUNK WITH CALLBACK_TOKEN: {:?}",
                    callback_token.clone(),
                );

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
                                slog::info!(
                                    logger,
                                    "==[ STREAMING_SPAWN ]==> REQUESTED CHUNK: {:?}",
                                    body.len(),
                                );
                                slog::info!(
                                    logger,
                                    "==[ STREAMING_SPAWN ]==> REQUESTED CHUNK TOKEN: {:?}",
                                    token.clone(),
                                );

                                if !skip_validation  {
                                    let is_chunk_valid = req_validation::validate_chunk(
                                        StreamingCallbackHttpResponse { body: body.clone(), token: token.clone() },
                                        canister_id.clone(),
                                        &agent,
                                        &parts.uri,
                                        logger.clone(),
                                    );
                                    if is_chunk_valid.is_err() {
                                        slog::debug!(logger, "Error chunk_body_valid is not valid");
                                        sender.abort();
                                        break;
                                    }
                                }
                               
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
            let body_valid = req_validation::validate(
                &headers_data,
                &canister_id,
                &agent,
                &parts.uri,
                &http_response.body,
                logger.clone(),
            );
            if body_valid.is_err() {
                return Ok(Response::builder()
                    .status(StatusCode::INTERNAL_SERVER_ERROR)
                    .body(body_valid.unwrap_err().into())
                    .unwrap());
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
    slog::trace!(logger, "[[ INCOMING_REQUEST_RESPONSE ]] ==> STATUS:{} || HEADERS: {:?}", response.status().to_string(), response.headers());
    Ok(response)
}

fn skip_validation(url: &hyper::Uri) -> bool {
    url.query()
        .map(|query| if query.contains("_raw") { true } else { false })
        .unwrap_or(false)
}

fn ok() -> Result<Response<Body>, Box<dyn Error>> {
    Ok(Response::builder()
        .status(StatusCode::OK)
        .body("OK".into())?)
}

fn unable_to_fetch_root_key() -> Result<Response<Body>, Box<dyn Error>> {
    Ok(Response::builder()
        .status(StatusCode::INTERNAL_SERVER_ERROR)
        .body("Unable to fetch root key".into())?)
}

#[derive(Clone, Debug)]
pub struct TargetCanisterParams {
    canister_id: Principal,
    found_uri:  String,
}

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
    let request_uri = request.uri();
    slog::trace!(logger, "[[ INCOMING_REQUEST ]] ==> URI:{} || HEADERS: {:?}", request_uri, request.headers());
    let result = if request_uri.path().starts_with("/healthcheck") {
        ok()
    } else {
        let agent = Arc::new(
            ic_agent::Agent::builder()
                .with_transport(ReqwestHttpReplicaV2Transport::create(replica_url).unwrap())
                .build()
                .expect("Could not create agent..."),
        );
        if fetch_root_key && agent.fetch_root_key().await.is_err() {
            unable_to_fetch_root_key()
        } else {
            let request_uri = request.uri();
            slog::trace!(logger, "Request URI: {:?}", request_uri.clone());
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
        
            forward_request(
                request,
                agent,
                redis_param.as_ref().as_ref(),
                phonebook_param.as_ref(),
                logger.clone(),
                TargetCanisterParams { canister_id, found_uri },
            )
            .await
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
