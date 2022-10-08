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
RUN wget https://github.com/dfinity/vessel/releases/download/v0.6.4/vessel-linux64 --output-document=vessel && vessel

COPY ../origyn_nft ./origyn_nft/
COPY ../phonebook ./phonebook/

WORKDIR /origyn_nft
RUN dfx start --background && \
    dfx canister create origyn_nft_reference && \
    dfx build origyn_nft_reference && \
    cp .dfx/local/canisters/origyn_nft_reference ../builds/origyn_nft && \
    rm ../origyn_nft



WORKDIR /phonebook
RUN dfx start --background && \
    dfx canister create phonebook && \
    dfx build phonebook && \
    cp .dfx/local/canisters/phonebook ../builds/phonebook && \
    rm ../phonebook

CMD dfx start 