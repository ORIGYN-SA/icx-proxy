vcl 4.1;

backend default {
    .host = "localhost";
    .port = "3000";
    .connect_timeout = 600s;
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 600s;
}

sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.V-Cache = "HIT";
        set resp.http.V-Cache-Hits = obj.hits;
    }
    else {
        set resp.http.V-Cache = "MISS";
    }
}
sub vcl_recv {
    if (req.url ~ "^.*/impossible_pass.*$" ) {
        return (pass);
    }
}

sub vcl_backend_response {
    if (beresp.status == 200) {
        unset beresp.http.Cache-Control;
        set beresp.http.Cache-Control = "public; max-age=1209600";
        set beresp.ttl = 14d;
    }
    if (bereq.url ~ "^.*/impossible_pass.*$" ) {
        unset beresp.http.Cache-Control;
        set beresp.http.Cache-Control = "public; max-age=1209600";
        set beresp.ttl = 14d;
    }
    set beresp.http.Served-By = beresp.backend.name;
    set beresp.http.V-Cache-TTL = beresp.ttl;
    set beresp.http.V-Cache-Grace = beresp.grace;

}
