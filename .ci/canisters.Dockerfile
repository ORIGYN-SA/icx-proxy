FROM rust:1.58.1 as rust_builder
WORKDIR /icx_proxy
COPY ./src ./src/
COPY ./Cargo* ./
RUN cargo build --release

FROM --platform=linux/amd64 debian:bullseye-slim
RUN apt-get update  
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
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

RUN sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"
WORKDIR /usr/local/bin/
ADD https://github.com/dfinity/vessel/releases/download/v0.6.4/vessel-linux64 vessel
RUN chmod +x vessel
COPY ./origyn_nft ./origyn_nft/
COPY ./phone_book ./phone_book/
COPY --from=rust_builder /icx_proxy/target/release/icx-proxy ./icx-proxy
EXPOSE 3000 8000

RUN cd origyn_nft && \
    dfx start --background --emulator && \
    dfx canister create origyn_nft_reference && \
    dfx build origyn_nft_reference && \
    cd ../phone_book && \
    dfx canister create phone_book && \
    dfx build phone_book

CMD ADMIN_PRINCIPAL=$(dfx identity get-principal) cd origyn_nft && \
    dfx start --background --emulator && \
    dfx deploy origyn_nft_reference --argument "(record {owner = principal \"$ADMIN_PRINCIPAL\"; storage_space = null})" && \
    cd ../phone_book && \
    dfx deploy phone_book --argument "(principal \"$ADMIN_PRINCIPAL\")" && \
    icx-proxy --debug -v --log "stderr" --replica "http://localhost:8000" --address 0.0.0.0:3000 --redis-url "redis://localhost:6379" --phonebook-id "$(dfx canister id phonebook)"
