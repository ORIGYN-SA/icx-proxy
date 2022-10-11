FROM rust:1.58.1 as rust_builder
WORKDIR /icx_proxy
COPY ./src ./src/
COPY ./Cargo* ./
RUN cargo build --release
CMD ./target/release/icx-proxy --debug -v --log "stderr" --replica "http://localhost:8000" --address 0.0.0.0:3000 --redis-url "redis://localhost:6379" --phonebook-id "$(dfx canister id phonebook)"

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
COPY --from=rust_builder ./icx_proxy/target/release/icx-proxy ./icx-proxy
RUN chmod +x ./icx-proxy
ADD https://github.com/dfinity/vessel/releases/download/v0.6.4/vessel-linux64 vessel
RUN chmod +x vessel

COPY ./origyn_nft ./origyn_nft/
COPY ./phone_book ./phone_book/

COPY ./.ci/deploy_nft_canister.sh ./deploy_nft_canister.sh
COPY ./.ci/deploy_phonebook_canister.sh ./deploy_phonebook_canister.sh

RUN chmod +x ./deploy_nft_canister.sh
RUN chmod +x ./deploy_phonebook_canister.sh

EXPOSE 3000 8000

RUN ./deploy_nft_canister.sh
RUN  ./deploy_phonebook_canister.sh
# CMD sleep 8888
# CMD icx-proxy --debug -v --log "stderr" --replica "http://localhost:8000" --address 0.0.0.0:3000 --redis-url "redis://localhost:6379" --phonebook-id "$(dfx canister id phonebook)"
CMD cd origyn_nft &&\
dfx start --background --emulator &&\
cd .. &&\
icx-proxy --debug -v --log "stderr" --replica "http://localhost:8000" --address 0.0.0.0:3000 --redis-url "redis://localhost:6379" --phonebook-id "$(dfx canister id phonebook)"
