FROM rust:1.58.1

RUN cargo install icx-proxy

EXPOSE 5000

CMD ["icx-proxy", "--replica", "https://ic0.app", "--address", "0.0.0.0:5000","--dns-alias","uefa_nfts4g:r5m5i-tiaaa-aaaaj-acgaq-cai"]
