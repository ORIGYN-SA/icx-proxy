use crate::config::dns_canister_rule::DnsCanisterRule;
use candid::{Decode, Encode};
use core::convert::From;
use ic_agent::agent::http_transport::ReqwestHttpReplicaV2Transport;
use ic_agent::ic_types::Principal;
use ic_agent::Agent;
use redis::aio::MultiplexedConnection;
use redis::AsyncCommands;
use std::cmp::Reverse;
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

/// Configuration for determination of Domain Name to Principal
#[derive(Clone)]
pub struct DnsCanisterConfig {
    rules: Vec<DnsCanisterRule>,
    //parameter is optional to simplify test (avoid to have a redis mock)
    redis_param: Option<(
        //use a mutex because the connection is only use in &mut mode. No read done.
        Arc<Mutex<MultiplexedConnection>>,
        mpsc::Sender<(String, String)>,
    )>,
    logger: Option<slog::Logger>,
    //the same for the phone book canister.
}

impl DnsCanisterConfig {
    /// Create a DnsCanisterConfig instance from command-line configuration.
    /// dns_aliases: 0 or more entries of the form of dns.alias:canister-id
    /// dns_suffixes: 0 or more domain names which will match as a suffix
    ///Redis Cache is optional to simplify local test.
    ///Runtime call force the cache.
    pub async fn new(
        dns_aliases: &[String],
        dns_suffixes: &[String],
        redis_param: Option<(&str, mpsc::Sender<(String, String)>)>,
        logger: Option<slog::Logger>,
    ) -> anyhow::Result<DnsCanisterConfig> {
        let mut rules = vec![];
        for suffix in dns_suffixes {
            rules.push(DnsCanisterRule::new_suffix(suffix));
        }
        for alias in dns_aliases {
            rules.push(DnsCanisterRule::new_alias(alias)?);
        }
        // Check suffixes first (via stable sort), because they will only match
        // if actually preceded by a canister id.
        rules.sort_by_key(|x| Reverse(x.dns_suffix.len()));

        let redis_param = if let Some((client, cache)) = redis_param.and_then(|(url, cache)| {
            redis::Client::open(url)
                .map(|client| (client, cache))
                .or_else(|err| {
                    logger.as_ref().map(|logger| {
                        slog::error!(
                            &logger,
                            "Error Open Redis client error: {}. No cache activated",
                            err
                        );
                    });
                    Err(err)
                })
                .ok()
        }) {
            client.get_multiplexed_tokio_connection().await.map(|conn| (Arc::new(Mutex::new(conn)), cache))
                    .or_else(|err| {
                    logger.as_ref().map(|logger| {
                        slog::error!(
                            &logger,
                            "Error Redis client get multiplexed connection error: {}. No cache activated",
                            err
                        );
                    });
                    Err(err)
                })
               .ok()
        } else {
            None
        };

        Ok(DnsCanisterConfig {
            rules,
            redis_param,
            logger,
        })
    }

    /*pub fn add_alias_rule(&mut self, alias: &str, canister_id: &str) -> anyhow::Result<()> {
        let rule = DnsCanisterRule::new_alias(&format!("{}:{}", alias, canister_id))?;
        self.rules.push(rule);
        Ok(())
    }*/

    /// Return the Principal of the canister that domain name matches the name.
    ///
    /// the specified name is expected to be the domain name of the DnsCanisterRule,
    /// but may contain upper- or lower-case characters.
    pub async fn resolve_canister_id_from_name(
        &self,
        name: &str,
        phonebook_param: Option<&PhoneBookCanisterParam>,
    ) -> Option<Principal> {
        //get canister from loaded rules then from redis cache.
        let found_principal = match self.rules.iter().find_map(|rule| rule.lookup_name(&name)) {
            Some(principal) => Some(principal),
            None => {
                //call redis if the cache is activated
                if let Some((redis_connection, _)) = self.redis_param.as_ref() {
                    let mut redis_connection = redis_connection.as_ref().lock().await;

                    redis_connection
                        .get::<_, String>(&name)
                        .await
                        .and_then(|s| {
                            println!("get canister id from redis: {}", s);
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
                }
            }
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
                        self.logger.as_ref().map(|logger| {
                            slog::error!(
                                logger,
                                "Error Phone Book canister query call failed: {}",
                                err
                            )
                        });
                    })
                    .ok()?;
                let canister_list = Decode!(response.as_slice(), Option<Vec<Principal>>)
                    .map_err(|err| {
                        self.logger.as_ref().map(|logger| {
                            slog::error!(
                                logger,
                                "Error during Phone Book canister reponse decoding: {}",
                                err
                            )
                        });
                    })
                    .ok()?;

                self.logger.as_ref().map(|logger| {
                    slog::info!(
                        logger,
                        "Get canister id from phone book response: {:?}",
                        canister_list
                    )
                });

                let found_principal = canister_list.and_then(|canister_list| {
                    (canister_list.len() > 0)
                        .then(|| self.redis_param.as_ref())
                        .and_then(|param| param)
                        .map(|(_, redis_cache_tx)| {
                            redis_cache_tx
                                .try_send((name.to_string(), canister_list[0].to_string()))
                                .map_err(|err| {
                                    self.logger.as_ref().map(|logger| {
                                        slog::error!(
                                    logger,
                                    "Error could not send canister_id to the Redis channel: {}",
                                    err
                                )
                                    });
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

    /*
    /// Return the Principal of the canister that matches the host name.
    ///
    /// split_hostname is expected to be the hostname split by '.',
    /// but may contain upper- or lower-case characters.
    //REMOVED because host name resolution is not use.
    pub fn resolve_canister_id_from_split_hostname(
        &self,
        split_hostname: &[&str],
    ) -> Option<Principal> {
        let split_hostname_lowercase: Vec<String> = split_hostname
            .iter()
            .map(|s| s.to_ascii_lowercase())
            .collect();
        self.rules
            .iter()
            .find_map(|rule| rule.lookup(&split_hostname_lowercase))
    }*/
}

impl From<&DnsCanisterConfig> for (Vec<String>, Vec<String>) {
    fn from(config: &DnsCanisterConfig) -> Self {
        let aliases = config
            .rules
            .iter()
            .filter_map(|r| {
                if r.is_alias() {
                    Some(r.to_string())
                } else {
                    None
                }
            })
            .collect();
        let suffix = config
            .rules
            .iter()
            .filter_map(|r| {
                if !r.is_alias() {
                    Some(r.to_string())
                } else {
                    None
                }
            })
            .collect();
        (aliases, suffix)
    }
}

//REMOVED because host name resolution not use.
/*#[cfg(test)]
mod tests {
    use crate::config::dns_canister_config::DnsCanisterConfig;
    use ic_agent::ic_types::Principal;

    #[test]
    fn matches_whole_hostname() {
        let dns_aliases =
            parse_dns_aliases(vec!["happy.little.domain.name:r7inp-6aaaa-aaaaa-aaabq-cai"])
                .unwrap();

        assert_eq!(
            dns_aliases
                .resolve_canister_id_from_split_hostname(&["happy", "little", "domain", "name"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        )
    }

    #[test]
    fn matches_partial_hostname() {
        let dns_aliases =
            parse_dns_aliases(vec!["little.domain.name:r7inp-6aaaa-aaaaa-aaabq-cai"]).unwrap();

        assert_eq!(
            dns_aliases
                .resolve_canister_id_from_split_hostname(&["happy", "little", "domain", "name"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        )
    }

    #[test]
    fn extraneous_does_not_match() {
        let dns_aliases = parse_dns_aliases(vec![
            "very.happy.little.domain.name:r7inp-6aaaa-aaaaa-aaabq-cai",
        ])
        .unwrap();

        assert_eq!(
            dns_aliases
                .resolve_canister_id_from_split_hostname(&["happy", "little", "domain", "name"]),
            None
        )
    }

    #[test]
    fn case_insensitive_match() {
        let dns_aliases =
            parse_dns_aliases(vec!["lItTlE.doMain.nAMe:r7inp-6aaaa-aaaaa-aaabq-cai"]).unwrap();

        assert_eq!(
            dns_aliases
                .resolve_canister_id_from_split_hostname(&["hAPpy", "littLE", "doMAin", "NAme"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        )
    }

    #[test]
    fn chooses_among_many() {
        let dns_aliases = parse_dns_aliases(vec![
            "happy.little.domain.name:r7inp-6aaaa-aaaaa-aaabq-cai",
            "ecstatic.domain.name:rrkah-fqaaa-aaaaa-aaaaq-cai",
        ])
        .unwrap();

        assert_eq!(
            dns_aliases
                .resolve_canister_id_from_split_hostname(&["happy", "little", "domain", "name"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        );

        assert_eq!(
            dns_aliases.resolve_canister_id_from_split_hostname(&["ecstatic", "domain", "name"]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        );

        assert_eq!(
            dns_aliases
                .resolve_canister_id_from_split_hostname(&["super", "ecstatic", "domain", "name"]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        )
    }

    #[test]
    fn chooses_first_match() {
        let dns_aliases = parse_dns_aliases(vec![
            "specific.of.many:r7inp-6aaaa-aaaaa-aaabq-cai",
            "of.many:rrkah-fqaaa-aaaaa-aaaaq-cai",
        ])
        .unwrap();

        assert_eq!(
            dns_aliases.resolve_canister_id_from_split_hostname(&["specific", "of", "many"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        );
        assert_eq!(
            dns_aliases
                .resolve_canister_id_from_split_hostname(&["more", "specific", "of", "many"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        );

        assert_eq!(
            dns_aliases.resolve_canister_id_from_split_hostname(&["another", "of", "many"]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        )
    }

    #[test]
    fn searches_longest_to_shortest() {
        // If we checked these in the order passed, a.b.c would erroneously resolve
        // to the canister id associated with b.c
        let dns_aliases = parse_dns_aliases(vec![
            "b.c:rrkah-fqaaa-aaaaa-aaaaq-cai",
            "a.b.c:r7inp-6aaaa-aaaaa-aaabq-cai",
        ])
        .unwrap();

        assert_eq!(
            dns_aliases.resolve_canister_id_from_split_hostname(&["a", "b", "c"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        );
        assert_eq!(
            dns_aliases.resolve_canister_id_from_split_hostname(&["d", "b", "c"]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        );
    }

    #[test]
    fn searches_longest_to_shortest_even_if_already_ordered() {
        // Similar to searches_longest_to_shortest, just to ensure that
        // we do the right thing no matter which order they are passed.
        let dns_aliases = parse_dns_aliases(vec![
            "a.b.c:r7inp-6aaaa-aaaaa-aaabq-cai",
            "b.c:rrkah-fqaaa-aaaaa-aaaaq-cai",
        ])
        .unwrap();

        assert_eq!(
            dns_aliases.resolve_canister_id_from_split_hostname(&["a", "b", "c"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        );
        assert_eq!(
            dns_aliases.resolve_canister_id_from_split_hostname(&["d", "b", "c"]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        );
    }

    #[test]
    fn searches_longest_to_shortest_not_alpha() {
        // Similar to searches_longest_to_shortest, but make sure we
        // don't happen to get there by sorting alphabetically
        let dns_aliases = parse_dns_aliases(vec![
            "x.c:rrkah-fqaaa-aaaaa-aaaaq-cai",
            "a.x.c:r7inp-6aaaa-aaaaa-aaabq-cai",
        ])
        .unwrap();

        assert_eq!(
            dns_aliases.resolve_canister_id_from_split_hostname(&["a", "x", "c"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        );
        assert_eq!(
            dns_aliases.resolve_canister_id_from_split_hostname(&["d", "x", "c"]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        );
    }

    #[test]
    fn searches_longest_to_shortest_not_alpha_reversed() {
        // Similar to searches_longest_to_shortest, but make sure we
        // don't happen to get there by sorting alphabetically/reversed
        let dns_aliases = parse_dns_aliases(vec![
            "a.c:rrkah-fqaaa-aaaaa-aaaaq-cai",
            "x.a.c:r7inp-6aaaa-aaaaa-aaabq-cai",
        ])
        .unwrap();

        assert_eq!(
            dns_aliases.resolve_canister_id_from_split_hostname(&["x", "a", "c"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        );
        assert_eq!(
            dns_aliases.resolve_canister_id_from_split_hostname(&["d", "a", "c"]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        );
    }

    #[test]
    fn dns_suffix_localhost_canister_found() {
        let config = parse_config(vec![], vec!["localhost"]).unwrap();

        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&[
                "rrkah-fqaaa-aaaaa-aaaaq-cai",
                "localhost"
            ]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        );
        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&[
                "r7inp-6aaaa-aaaaa-aaabq-cai",
                "localhost"
            ]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        )
    }

    #[test]
    fn dns_suffix_localhost_more_domain_names_ok() {
        let config = parse_config(vec![], vec!["localhost"]).unwrap();

        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&[
                "more",
                "rrkah-fqaaa-aaaaa-aaaaq-cai",
                "localhost"
            ]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        );
        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&[
                "even",
                "more",
                "r7inp-6aaaa-aaaaa-aaabq-cai",
                "localhost"
            ]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        )
    }

    #[test]
    fn dns_suffix_must_immediately_precede_suffix() {
        let config = parse_config(vec![], vec!["localhost"]).unwrap();

        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&[
                "rrkah-fqaaa-aaaaa-aaaaq-cai",
                "nope",
                "localhost"
            ]),
            None
        );
    }

    #[test]
    fn dns_suffix_longer_suffix_ok() {
        let config = parse_config(vec![], vec!["a.b.c"]).unwrap();

        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&[
                "rrkah-fqaaa-aaaaa-aaaaq-cai",
                "a",
                "b",
                "c"
            ]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        );
    }

    #[test]
    fn dns_suffix_longer_suffix_still_requires_exact_positionok() {
        let config = parse_config(vec![], vec!["a.b.c"]).unwrap();

        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&[
                "rrkah-fqaaa-aaaaa-aaaaq-cai",
                "no",
                "a",
                "b",
                "c"
            ]),
            None
        );
    }

    #[test]
    fn dns_suffix_longer_suffix_can_be_preceded_by_more() {
        let config = parse_config(vec![], vec!["a.b.c"]).unwrap();

        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&[
                "yes",
                "rrkah-fqaaa-aaaaa-aaaaq-cai",
                "a",
                "b",
                "c"
            ]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        );
    }

    #[test]
    fn dns_suffix_ignores_earlier_canister_ids() {
        let config = parse_config(vec![], vec!["a.b.c"]).unwrap();

        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&[
                "r7inp-6aaaa-aaaaa-aaabq-cai", // not seen/returned
                "rrkah-fqaaa-aaaaa-aaaaq-cai",
                "a",
                "b",
                "c"
            ]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        );
    }

    #[test]
    fn aliases_and_suffixes() {
        let config = parse_config(
            vec![
                "a.b.c:r7inp-6aaaa-aaaaa-aaabq-cai",
                "d.e:rrkah-fqaaa-aaaaa-aaaaq-cai",
            ],
            vec!["g.h.i"],
        )
        .unwrap();

        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&["a", "b", "c"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        );
        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&["d", "e",]),
            Some(Principal::from_text("rrkah-fqaaa-aaaaa-aaaaq-cai").unwrap())
        );
        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&[
                "ryjl3-tyaaa-aaaaa-aaaba-cai",
                "g",
                "h",
                "i",
            ]),
            Some(Principal::from_text("ryjl3-tyaaa-aaaaa-aaaba-cai").unwrap())
        );
    }

    #[test]
    fn same_alias_and_suffix_prefers_alias() {
        // because the suffix will only match if preceded by a canister id
        let config =
            parse_config(vec!["a.b.c:r7inp-6aaaa-aaaaa-aaabq-cai"], vec!["a.b.c"]).unwrap();

        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&["a", "b", "c"]),
            Some(Principal::from_text("r7inp-6aaaa-aaaaa-aaabq-cai").unwrap())
        );
        assert_eq!(
            config.resolve_canister_id_from_split_hostname(&[
                "ryjl3-tyaaa-aaaaa-aaaba-cai",
                "a",
                "b",
                "c"
            ]),
            Some(Principal::from_text("ryjl3-tyaaa-aaaaa-aaaba-cai").unwrap())
        );
    }

    fn parse_dns_aliases(aliases: Vec<&str>) -> anyhow::Result<DnsCanisterConfig> {
        let aliases: Vec<String> = aliases.iter().map(|&s| String::from(s)).collect();
        DnsCanisterConfig::new(&aliases, &[], "".to_string(), "".to_string())
    }

    fn parse_config(aliases: Vec<&str>, suffixes: Vec<&str>) -> anyhow::Result<DnsCanisterConfig> {
        let aliases: Vec<String> = aliases.iter().map(|&s| String::from(s)).collect();
        let suffixes: Vec<String> = suffixes.iter().map(|&s| String::from(s)).collect();
        DnsCanisterConfig::new(&aliases, &suffixes, "".to_string(), "".to_string())
    }

}*/
