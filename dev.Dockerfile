FROM rust:1.58.1

RUN cargo install icx-proxy

EXPOSE 443

CMD ["icx-proxy", "--replica", "https://ic0.app", "--address", "0.0.0.0:443"]