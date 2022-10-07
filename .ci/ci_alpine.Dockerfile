FROM rust:alpine3.16 as rust_builder
WORKDIR /app
COPY ./src ./src/
COPY ./Cargo* ./
RUN apk add musl-dev 
RUN apk add musl-gcc
# target platform needed for alpine
RUN rustup target add x86_64-unknown-linux-musl
RUN cargo build --target x86_64-unknown-linux-musl --release

# FROM alpine:latest
# RUN apk add libc6-compat libgcc
# RUN apt-get update  
# RUN apt-get install libssl-dev
# RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
#         build-essential \
#         ca-certificates \
#         libdigest-sha-perl \
#         cmake \
#         curl \
#         git \
#         rsync \
#         ssh \
#         libssl-dev \
#         pkg-config && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*
# COPY --from=rust_builder /app/target/release/icx-proxy .
# CMD ls -la
CMD ./icx-proxy --debug -v --log "stderr" --replica "https://ic0.app" --address 0.0.0.0:3000 --redis-url "redis://tf-icx-proxy-redis-cluster-qa-us-east-1.tvmdlr.ng.0001.use1.cache.amazonaws.com:6379" --phonebook-id "ngrpb-5qaaa-aaaaj-adz7a-cai"
# COPY --from=redis_builder /usr/local/bin/redis-cli /usr/local/bin/redis-cli
# COPY --from=rust_builder /usr/local/cargo/bin/cargo /usr/local/bin/cargo