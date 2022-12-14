FROM rust:1.58.1
COPY . .
RUN cargo build
EXPOSE 5000
#CMD ["icx-proxy", "--replica", "https://ic0.app", "--address", "0.0.0.0:443","--dns-alias","uefa_nfts4g:r5m5i-tiaaa-aaaaj-acgaq-cai"]
CMD cargo run -- --debug -v --log "stderr" --replica "https://ic0.app" --address 0.0.0.0:5000 --redis-url "redis://redis:6379" --phonebook-id "ngrpb-5qaaa-aaaaj-adz7a-cai"
