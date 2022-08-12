FROM alpine

RUN apk add varnish
ENV VARNISH_MEMORY 256M
COPY scripts/varnish-entrypoint  ./
COPY scripts/default.vcl /etc/varnish/
EXPOSE 5000

CMD ./varnish-entrypoint
