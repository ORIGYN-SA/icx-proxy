# `icx-proxy`

A command line tool to serve as a gateway for a Internet Computer replica. This is being deployed to production at [prptl.io](https://prptl.io/).

## Uri convertion

The proxy transform the incoming http request to a canister call and return the canister answer.
The base transformation pattern is:

```
https://prptl.io/-/<canister-id>/-/y/some/uri => <canister-id>.raw.ic0.app/-y/some/uri
```

The `<canister-id>` can be either an alias or an actual canister id. In case it is an alias, the phonebook canister will be used to check the canister id of the alias.

x can be a canister id or an alias that is mapped to a canister id.

### Example:

The URL:

https://prptl.io/-/brain-matters-dev/-/epithalamus-amygdala-diencephalon/ex

becomes

https://mludz-biaaa-aaaal-qbhwa-cai.raw.ic0.app/-/epithalamus-amygdala-diencephalon/ex

In the example above we can see that the alias is `brain-matters-dev`. This means that icx-proxy will query the phonebook canister to get its canister id.

### Definition of alias

Alias mapping is defined using the phone book canister. An alias for each canister id is inserted in the phonebook canister.

The canister id of the phonebook canister id: `ngrpb-5qaaa-aaaaj-adz7a-cai`.

The interface is:

```
type PhoneBook =
 service {
   insert: (Name, Canisters) -> (opt Canisters);
   lookup: (Name) -> (opt vec Canister) query;
   update_admin: (Canisters) -> (Canisters);
 };
type Name = text;
type Canisters = vec Canister;
type Canister = principal;
service : (principal) -> PhoneBook
```

Alias are added using the insert canister call.

## Alias use

When the proxy server is call, the uri is decoded and if it found an alias in the uri, it's mapped to a canister id.
The mapping is done as follow:

- call the Redis cache server to see if it exists in the cache.
- If not call the phone book canister with the lookup call.
- if not found, return an error.
- if an alias is found, call the canister mapped by the alias and return the answer
- if an alias is found and not present in the cache, add it after the end of the request.

## Command line configuration

To start the proxy, you must provide these parameters:

- --replica: define the IC network to connect to the canister. ex: `https://ic0.app` . Several replica can be defined to start multiple listener that connect to multiple IC network or sub network.
- --redis-url: The url to connect to the redis cache. ex: `redis://localhost:6379/`. If a login/ pass is mandatory, it must be added to the url.
- --phonebook-id. Id of the phone book canister. ex: `ngrpb-5qaaa-aaaaj-adz7a-cai`

Optional:

- redis-cache-timeout: define the timeout of acched data. Default 24h

Exemple of start command:

```
icx-proxy --replica "https://ic0.app" --redis-url "redis://localhost:6379/" --phonebook-id "ngrpb-5qaaa-aaaaj-adz7a-cai"
```

## Running locally

### Running with docker compose

You can get the whole stack up by running:

```
docker-compose up
```

### Running without docker-compose

1. Start a redis local server

```
docker run -p 6379:6379 redis:5.0
```

2. Start icx-proxy server

```bash
cargo run -- --debug -v --log "stderr" --replica "https://ic0.app" --redis-url "redis://localhost:6379/" --phonebook-id "ngrpb-5qaaa-aaaaj-adz7a-cai"
```

To add more trace add a -v

```bash
cargo run -- --debug -v -v --log "stderr" --replica "https://ic0.app" --redis-url "redis://localhost:6379/" --phonebook-id "ngrpb-5qaaa-aaaaj-adz7a-cai"
```

## Example of connection test

```
http://127.0.0.1:3000/-/brain-matters-dev/-/epithalamus-amygdala-diencephalon
http://127.0.0.1:3000/-/brain-matters-dev/-/epithalamus-amygdala-diencephalon/ex
http://127.0.0.1:3000/-/brain-matters-dev/-/epithalamus-amygdala-diencephalon/info
```

## Skip validation

Add the `_raw` tag to the URL query string to skip certificate validation of canister answer.
ex:

http://127.0.0.1:3000/-/brain-matters-dev/-/epithalamus-amygdala-diencephalon?_raw_

## Health Check

There an health check entry point to detect if the service is still running.
the uri is: /healthcheck and it returns 200 / OK

## Usage

Once installed, using `icx-proxy --help` will show the usage message and all the flags.

## Current environment information

We have two environments (`development`/`production`) running as services on our docker swarm ([portainer.origyn.ch](https://portainer.origyn.ch])).

A CI/CD job is being triggered on each push to develop/master branch to build the rosetta api and update the docker swarm service.

Development URL: https://dev.icx-proxy.origyn.ch

Production URL: https://prptl.io
