vcl 4.1;
import std;

include "snippet.vcl";

backend default {
    .host = "icx";
    .port = "5000";
}

sub vcl_recv
{
     unset req.http.Cookie;
}

sub vcl_backend_response {
  set beresp.ttl = 1h;
}