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
# WORKDIR /dfx
RUN wget https://github.com/dfinity/vessel/releases/download/v0.6.4/vessel-linux64 --output-document=vessel && vessel
# COPY ../origyn_nft ./origyn_nft/
COPY ../phonebook ./phonebook/
WORKDIR /phonebook
RUN dfx build
CMD dfx start