use async_trait::async_trait;
use candid::{Decode, Encode};
use core::convert::From;
use ic_agent::agent::http_transport::ReqwestHttpReplicaV2Transport;
use ic_agent::ic_types::Principal;
use ic_agent::Agent;
use redis::aio::MultiplexedConnection;
use redis::AsyncCommands;
use std::sync::Arc;
use tokio::sync::{mpsc, Mutex};

#[derive(Clone, Debug)]
pub struct PhoneBookCanisterParam {
    canister_id: Principal,
    agent: Agent,
}
impl PhoneBookCanisterParam {
    pub fn new(
        phonebook_id: &str,
        network_url: &str,
        logger: &slog::Logger,
    ) -> Result<PhoneBookCanisterParam, String> {
        Principal::from_text(phonebook_id)
            .or_else(|err| {
                slog::error!(
                    logger,
                    "Error Phone book canister id not a principal: {}, id:{}",
                    err,
                    phonebook_id,
                );
                Err("Error Phone book canister id not a principal".to_string())
            })
            .and_then(|principal| {
                ReqwestHttpReplicaV2Transport::create(network_url)
                    .and_then(|transport| Agent::builder().with_transport(transport).build())
                    .map(|agent| PhoneBookCanisterParam {
                        canister_id: principal,
                        agent,
                    })
                    .map_err(|err| {
                        slog::error!(
                            logger,
                            "Error Phone book canister connection error: {}",
                            err
                        );
                        "Error Phone book agent connection error".to_string()
                    })
            })
    }
}

#[derive(Clone)]
pub struct RedisParam {
    connection: Arc<Mutex<MultiplexedConnection>>,
    redis_cache_tx: mpsc::Sender<(String, String)>,
}

impl RedisParam {
    pub async fn try_new(
        redis_url: Option<&str>,
        redis_cache_tx: Option<mpsc::Sender<(String, String)>>,
        logger: &slog::Logger,
    ) -> Option<Self> {
        if let Some((client, cache)) = redis_url.and_then(|url| {
            redis_cache_tx
                .map(|cache| (url, cache))
                .and_then(|(url, cache)| {
                    redis::Client::open(url)
                        .map(|client| (client, cache))
                        .or_else(|err| {
                            slog::error!(
                                &logger,
                                "Error Open Redis client error: {}. No cache activated",
                                err
                            );
                            Err(err)
                        })
                        .ok()
                })
        }) {
            let connection = client.get_multiplexed_tokio_connection().await.map(|conn| Arc::new(Mutex::new(conn)))
	                    .or_else(|err| {
	                        slog::error!(
	                            &logger,
	                            "Error Redis client get multiplexed connection error: {}. No cache activated",
	                            err
	                        );
	                    Err(err)
	                }).ok()?;
            Some(RedisParam {
                connection,
                redis_cache_tx: cache,
            })
        } else {
            None
        }
    }
}

pub async fn resolve_canister_id_from_uri(
    url: &hyper::Uri,
    redis_param: Option<&RedisParam>,
    phonebook_param: Option<&PhoneBookCanisterParam>,
    canister_id_resolver: impl ResolveCanisterId,
    logger: &slog::Logger,
) -> Option<(Principal, String)> {
    //    let (_, canister_id) = url::form_urlencoded::parse(url.query()?.as_bytes())
    //        .find(|(name, _)| name == "canisterId")?;
    //    Principal::from_text(canister_id.as_ref()).ok()

    let mut segment = path_segments(url)?;
    if let Some("-") = segment.next() {
        let x = segment.next()?;
        slog::info!(
            logger,
            "FIRST SEGMENT AS CANISTER IDENTYFIER: {:?}",
            x.clone(),
        );
        //detect if it's a canister id
        let id = match Principal::from_text(x) {
            Ok(id) => id,
            //not a caniter if, try to see if it's an alias.
            Err(_) => {
                canister_id_resolver
                    .resolve_canister_id_from_name(x, redis_param, phonebook_param, &logger)
                    .await?
            }
        };

        if let Some(collection) = segment.next() {
            let mut y = segment.clone().map(|s| format!("/{}", s)).collect::<String>();
            // detect if collection present in link 
            if collection.len() != 0 && String::from(collection.clone()).ne(&String::from("-")) {
                y = format!("/{}{}", collection, segment.map(|s| format!("/{}", s)).collect::<String>());
                slog::info!(
                    logger,
                    "SEGMENTS NEXT AFTER CANISTER ID: {:?}",
                    y.clone(),
                );
                //add query string.
                let uri = url.query().map(|q| format!("{}?{}", y, q)).unwrap_or(y);
                slog::info!(
                    logger,
                    "COLLECTION URI WITH QUERY STRING: {:?}",
                    uri.clone(),
                );
                return Some((id, uri));
            }

            if y.len() != 0 {
                //add query string.
                let uri = url.query().map(|q| format!("{}?{}", y, q)).unwrap_or(y);
                slog::info!(
                    logger,
                    "REGULAR URI WITH QUERY STRING: {:?}",
                    uri.clone(),
                );
                return Some((id, format!("/-{}", uri)));
            }
        }
    }
    None
}

fn path_segments(url: &hyper::Uri) -> Option<std::str::Split<'_, char>> {
    let path = url.path();
    if path.starts_with('/') {
        Some(path[1..].split('/'))
    } else {
        None
    }
}

#[async_trait]
pub trait ResolveCanisterId {
    async fn resolve_canister_id_from_name(
        &self,
        name: &str,
        redis_param: Option<&RedisParam>,
        phonebook_param: Option<&PhoneBookCanisterParam>,
        logger: &slog::Logger,
    ) -> Option<Principal>;
}

pub struct RealAccess;

#[async_trait]
impl ResolveCanisterId for RealAccess {
    async fn resolve_canister_id_from_name(
        &self,
        name: &str,
        redis_param: Option<&RedisParam>,
        phonebook_param: Option<&PhoneBookCanisterParam>,
        logger: &slog::Logger,
    ) -> Option<Principal> {
        //get canister id from redis cache.
        let found_principal = if let Some(RedisParam { connection, .. }) = redis_param.as_ref() {
            let mut redis_connection = connection.as_ref().lock().await;

            redis_connection
                .get::<_, String>(&name)
                .await
                .and_then(|s| {
                    Principal::from_text(s).map_err(|_| {
                        redis::RedisError::from((
                            redis::ErrorKind::TypeError,
                            "Redis canister id not a principal.",
                        ))
                    })
                })
                .ok()
        } else {
            None
        };

        //don't use closure because of async call not compatible with.
        //call phone book canister if not found.
        if let None = found_principal {
            if let Some(phone_book) = phonebook_param {
                //let canister_id = "r5m5i-tiaaa-aaaaj-acgaq-cai".to_string();
                let response = phone_book
                    .agent
                    .query(&phone_book.canister_id, "lookup")
                    .with_arg(&Encode!(&name).ok()?)
                    .call()
                    .await
                    .map_err(|err| {
                        slog::error!(
                            logger,
                            "Error Phone Book canister query call failed: {}",
                            err
                        );
                    })
                    .ok()?;
                let canister_list = Decode!(response.as_slice(), Option<Vec<Principal>>)
                    .map_err(|err| {
                        slog::error!(
                            logger,
                            "Error during Phone Book canister reponse decoding: {}",
                            err
                        );
                    })
                    .ok()?;

                slog::info!(
                    logger,
                    "Get canister id from phone book response: {:?}",
                    canister_list
                );

                let found_principal = canister_list.and_then(|canister_list| {
                    (canister_list.len() > 0)
                        .then(|| redis_param.as_ref())
                        .and_then(|param| param)
                        .map(|RedisParam { redis_cache_tx, .. }| {
                            redis_cache_tx
                                .try_send((name.to_string(), canister_list[0].to_string()))
                                .map_err(|err| {
                                    slog::error!(
                                        logger,
                                        "Error could not send canister_id to the Redis channel: {}",
                                        err
                                    );
                                })
                                .ok();
                            canister_list[0]
                        })
                });
                return found_principal;
            }
        }
        found_principal
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use hyper::http::Uri;
    use slog::Drain;

    #[derive(Clone, Debug)]
    pub struct TestAccess(String, String);

    #[async_trait]
    impl ResolveCanisterId for TestAccess {
        async fn resolve_canister_id_from_name(
            &self,
            name: &str,
            _redis_param: Option<&RedisParam>,
            _phonebook_param: Option<&PhoneBookCanisterParam>,
            _logger: &slog::Logger,
        ) -> Option<Principal> {
            (&self.0 == name).then(|| Principal::from_text(&self.1).unwrap())
        }
    }

    #[tokio::test]
    async fn test_resolve_canister_id_from_uri() {
        let decorator = slog_term::TermDecorator::new().build();
        let drain = slog_term::FullFormat::new(decorator).build().fuse();
        let drain = slog_async::Async::new(drain).build().fuse();

        let logger = slog::Logger::root(drain, slog::o!());
        let canister_resolver = TestAccess(
            "uefa_nfts4g".to_string(),
            "r5m5i-tiaaa-aaaaj-acgaq-cai".to_string(),
        );

        let uri = "/-/uefa_nfts4g/-/uefa_nfts4g_0".parse::<Uri>().unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        let (canister_id, uri) = res.unwrap();
        assert_eq!("/-/uefa_nfts4g_0", uri);
        assert_eq!("r5m5i-tiaaa-aaaaj-acgaq-cai", canister_id.to_string());
        let uri = "/-/r5m5i-tiaaa-aaaaj-acgaq-cai/-/uefa_nfts4g_0"
            .parse::<Uri>()
            .unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        let (canister_id, uri) = res.unwrap();
        assert_eq!("/-/uefa_nfts4g_0", uri);
        assert_eq!("r5m5i-tiaaa-aaaaj-acgaq-cai", canister_id.to_string());

        let uri = "/-/r5m5i-tiaaa-aaaaj-acgaq-cai/-/1".parse::<Uri>().unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        let (canister_id, uri) = res.unwrap();
        assert_eq!("/-/1", uri);
        assert_eq!("r5m5i-tiaaa-aaaaj-acgaq-cai", canister_id.to_string());

        let uri = "/-/r5m5i-tiaaa-aaaaj-acgaq-cai/-/1/ex"
            .parse::<Uri>()
            .unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        let (canister_id, uri) = res.unwrap();
        assert_eq!("/-/1/ex", uri);
        assert_eq!("r5m5i-tiaaa-aaaaj-acgaq-cai", canister_id.to_string());

        let uri = "/-/r5m5i-tiaaa-aaaaj-acgaq-cai/-/1/ex/yx"
            .parse::<Uri>()
            .unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        let (canister_id, uri) = res.unwrap();
        assert_eq!("/-/1/ex/yx", uri);
        assert_eq!("r5m5i-tiaaa-aaaaj-acgaq-cai", canister_id.to_string());

        let uri = "/-/r5m5i-tiaaa-aaaaj-acgaq-cai/-/1/ex/yx?q1=23&q2=33"
            .parse::<Uri>()
            .unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        let (canister_id, uri) = res.unwrap();
        assert_eq!("/-/1/ex/yx?q1=23&q2=33", uri);
        assert_eq!("r5m5i-tiaaa-aaaaj-acgaq-cai", canister_id.to_string());

        let uri = "/-/r5m5i-tiaaa-aaaaj-acgaq-cai/-/1/ex/yx?_raw"
            .parse::<Uri>()
            .unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        let (canister_id, uri) = res.unwrap();
        assert_eq!("/-/1/ex/yx?_raw", uri);
        assert_eq!("r5m5i-tiaaa-aaaaj-acgaq-cai", canister_id.to_string());

        //https://nft.origyn.network/x/-/y => Error
        let uri = "/uefa_nfts4g/-/uefa_nfts4g_0".parse::<Uri>().unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        assert!(res.is_none());
        //https://nft.origyn.network/-/x/y => Error
        let uri = "/-/uefa_nfts4g/uefa_nfts4g_0".parse::<Uri>().unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        assert!(res.is_none());
        //uefa_nfts3g can't be converted to a canister_id
        let uri = "/-/uefa_nfts3g/-/uefa_nfts4g_0".parse::<Uri>().unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        assert!(res.is_none());

        //https://nft.origyn.network/x/y => Error
        let uri = "/uefa_nfts4g/uefa_nfts4g_0".parse::<Uri>().unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        assert!(res.is_none());
        //https://nft.origyn.network/-/x => Error
        let uri = "/-/uefa_nfts4g".parse::<Uri>().unwrap();
        let res =
            resolve_canister_id_from_uri(&uri, None, None, canister_resolver.clone(), &logger)
                .await;
        assert!(res.is_none());
    }
}
