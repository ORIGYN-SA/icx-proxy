FROM --platform=linux/amd64 alpine:3.1.2
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

WORKDIR /dfx
RUN sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"
# COPY ./dfx_install.sh ./dfx_install.sh
# RUN sh ./dfx_install.sh
# RUN sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh | sed 's/[ "$_ostype" = Darwin ] && [ "$_cputype" = arm64 ];/[ "$_ostype" = Darwin ] && [ "$_cputype" = arm64 ] && [ "$_cputype" = aarch64 ];/')"

# COPY ../origyn_nft ./origyn_nft/
# COPY ../phonebook ./phonebook/

CMD dfx start