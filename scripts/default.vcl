vcl 4.1;

backend default {
    .host = "localhost";
    .port = "3000";
}

sub vcl_deliver {
    unset resp.http.Cache-Control;
}