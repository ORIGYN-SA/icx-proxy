# `icx-proxy`
A command line tool to serve as a gateway for a Internet Computer replica.

## specifing URI canister id alias
Alias that map a uri tag to a canister id can be defined. The base pattern is

https://nft.origyn.network/-/x/-/y/some/uri => x.ic0.app/-y/some/uri

### Static definition of tag alias
To define tag alias at startup, use the --dns-alias option of the icx-proxy, see the --help for more detail.

Ex:
```bash
icx-proxy --dns-alias "uefa_nfts4g:r5m5i-tiaaa-aaaaj-acgaq-cai"
```
to map uefa_nfts4g tag to r5m5i-tiaaa-aaaaj-acgaq-cai canister id.

With this setting, this url: https://nft.origyn.network/-/uefa_nfts4g/-/uefa_nfts4g_0 becomes https://r5m5i-tiaaa-aaaaj-acgaq-cai.raw.ic0.app/-/uefa_nft4g_0 

### Dynamic setting of canister tag alias
Canister alias can be defined dynamically using the entry point /admintag. The format is  /admintag/{tagname}/{canister_id}

The tag alias aren't persistent and must be defined after each restart. This entry is useful for test or to define a new canister id without restart. It should be added to the start command too so it'll be present after the next restart.

An authenticate X-API-KEY must be defined in the request: f69fdd4d-95c8-4aa1-966c-eaf791340946 to be authorized to add a tag alias.

Example of curl call: 
```bash
 curl -v -H "X-API-KEY: f69fdd4d-95c8-4aa1-966c-eaf791340946" http://127.0.0.1:3000/admintag/newtag/r5m5i-tiaaa-aaaaj-acgaq-cai
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
