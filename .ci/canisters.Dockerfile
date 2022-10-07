FROM debian:bullseye-slim
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
