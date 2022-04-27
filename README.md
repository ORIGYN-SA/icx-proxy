# `icx-proxy`
A command line tool to serve as a gateway for a Internet Computer replica.

## specifing URI alias
To use the new rules, use the --dns-alias option, see the --help for more detail.
Ex:
```bash
icx-proxy --dns-alias "uefa_nfts4g:r5m5i-tiaaa-aaaaj-acgaq-cai"
```
to map uefa_nfts4g tag to r5m5i-tiaaa-aaaaj-acgaq-cai canister id.
With this setting, this url: https://nft.origyn.network/-/uefa_nfts4g/-/uefa_nfts4g_0 becomes https://r5m5i-tiaaa-aaaaj-acgaq-cai.raw.ic0.app/-/uefa_nft4g_0 

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
