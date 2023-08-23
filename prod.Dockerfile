FROM rust:latest as builder

WORKDIR /app
COPY ./Cargo* rust-toolchain ./
COPY ./src ./src/

RUN cargo build --release

FROM ubuntu:20.04

COPY --from=builder /app/target/release/icx-proxy /bin/
RUN apt update && apt install -y ca-certificates
EXPOSE 5000

CMD icx-proxy --debug -v --log "stderr" --replica "https://icp-api.io" --address 0.0.0.0:5000 --redis-url "redis://redis:6379" --phonebook-id "ngrpb-5qaaa-aaaaj-adz7a-cai"

