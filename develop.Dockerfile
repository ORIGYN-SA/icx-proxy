FROM rust:1.58.1
COPY . .
RUN cargo build
EXPOSE 5000

CMD cargo run -- --debug -v --log "stderr" --replica "https://icp-api.io" --address 0.0.0.0:5000 --redis-url "redis://redis:6379" --phonebook-id "ngrpb-5qaaa-aaaaj-adz7a-cai"