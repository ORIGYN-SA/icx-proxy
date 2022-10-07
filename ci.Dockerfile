FROM redis:latest as redis_builder
FROM rust:1.58.1 as rust_builder
WORKDIR /app
COPY ./src ./src/
COPY ./Cargo* ./
RUN cargo build --release

FROM ubuntu:22.04
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        libdigest-sha-perl \
        cmake \
        curl \
        git \
        rsync \
        ssh \
        libssl-dev \
        pkg-config && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
COPY --from=rust_builder /app/target/release/icx-proxy /bin/
CMD icx-proxy --debug -v --log "stderr" --replica "https://ic0.app" --address 0.0.0.0:3000 --redis-url "redis://tf-icx-proxy-redis-cluster-qa-us-east-1.tvmdlr.ng.0001.use1.cache.amazonaws.com:6379" --phonebook-id "ngrpb-5qaaa-aaaaj-adz7a-cai"
# COPY --from=redis_builder /usr/local/bin/redis-cli /usr/local/bin/redis-cli
# COPY --from=rust_builder /usr/local/cargo/bin/cargo /usr/local/bin/cargo