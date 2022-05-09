# `icx-proxy`
A command line tool to serve as a gateway for a Internet Computer replica.

## Uri convertion
The proxy transform the incoming http request to a canister call and return the canister answer.
The base transformation pattern is:
https://nft.origyn.network/-/x/-/y/some/uri => x.ic0.app/-y/some/uri

x can be a canister id or an alias that is mapped to a canister id.

### Example:
```
The url: https://nft.origyn.network/-/r5m5i-tiaaa-aaaaj-acgaq-cai/-/uefa_nfts4g_0 becomes https://r5m5i-tiaaa-aaaaj-acgaq-cai.ic0.app/-/uefa_nft4g_0 

```

## Defining URI canister id alias

Alias map the  uri x tag to a canister id.

To map uefa_nfts4g tag to r5m5i-tiaaa-aaaaj-acgaq-cai canister id.

Example:
```
The url: https://nft.origyn.network/-/uefa_nfts4g/-/uefa_nfts4g_0 becomes https://r5m5i-tiaaa-aaaaj-acgaq-cai.raw.ic0.app/-/uefa_nft4g_0 

```

### Definition of alias

Alias mapping is defined using the phone book canister.

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
 * call the Redis cache server to see if it exists in the cache.
 * If not call the phone book canister with the lookup call.
 * if not found, return an error.
 * if an alias is found, call the canister mapped by the alias and return the answer
 * if an alias is found and not present in the cache, add it after the end of the request.

 
## Command line configuration
To start the proxy, you must provide these parameters:
 * --replica: define the IC network to connect to the canister. ex: "https://ic0.app" . Several replica can be defined to start multiple listener that connect to multiple IC network or sub network.
 * --redis-url: The url to connect to the redis cache. ex: "redis://localhost:6379/". If a login/ pass is mandatory, it must be added to the url.
 * --phonebook-id. Id of the phone book canister. ex: "ngrpb-5qaaa-aaaaj-adz7a-cai"

Exemple of start command:
```
icx-proxy --replica "https://ic0.app" --redis-url "redis://tf-icx-proxy-redis-cluster-dev-us-east-1-ro.tvmdlr.ng.0001.use1.cache.amazonaws.com:6379" --phonebook-id "ngrpb-5qaaa-aaaaj-adz7a-cai"
```

## Health Check
There an health check entry point to detect if the service is still running.
the uri is: /healthcheck and it returns 200 / OK

## Contributing
Please follow the guidelines in the [CONTRIBUTING.md](.github/CONTRIBUTING.md) document.

## Installing `icx-proxy`
One can install `icx-proxy` by running cargo;

```bash
cargo install icx-proxy
```

## Usage
Once installed, using `icx-proxy --help` will show the usage message and all the flags.

## Ecosystem
This is similar in principle to `dfx bootstrap`, but is simpler and more configurable. This also can replace a Replica when using the `--network` flag in `dfx`.
