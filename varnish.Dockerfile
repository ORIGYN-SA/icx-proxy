FROM alpine

RUN apk add varnish

COPY scripts/varnish-entrypoint  ./
COPY scripts/default.vcl /etc/varnish/
EXPOSE 5000

CMD ./varnish-entrypoint
