FROM varnish:alpine
COPY scripts/*.vcl /etc/varnish/
