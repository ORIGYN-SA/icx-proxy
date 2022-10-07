FROM rust:1.58.1 as rust_builder
WORKDIR /app
COPY ./src ./src/
COPY ./Cargo* ./
RUN cargo build --release

FROM debian:bullseye-slim
RUN apt-get update  
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libssl-dev &&  apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=rust_builder /app/target/release/icx-proxy /usr/local/bin/icx-proxy
EXPOSE 8000
CMD icx-proxy --debug -v --log "stderr" --replica "https://ic0.app" --address 0.0.0.0:3000 --redis-url "redis://tf-icx-proxy-redis-cluster-qa-us-east-1.tvmdlr.ng.0001.use1.cache.amazonaws.com:6379" --phonebook-id "ngrpb-5qaaa-aaaaj-adz7a-cai"
