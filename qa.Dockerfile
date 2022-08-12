FROM rust:latest as builder

WORKDIR /app
COPY ./Cargo* rust-toolchain ./
COPY ./src ./src/

RUN cargo build --release

FROM ubuntu:20.04

COPY --from=builder /app/target/release/icx-proxy /bin/
RUN apt update && apt install -y ca-certificates
EXPOSE 3000

CMD icx-proxy --debug -v --log "stderr" --replica "https://ic0.app" --address 0.0.0.0:3000 --redis-url "redis://tf-icx-proxy-redis-cluster-qa-us-east-1.tvmdlr.ng.0001.use1.cache.amazonaws.com:6379" --phonebook-id "ngrpb-5qaaa-aaaaj-adz7a-cai"

