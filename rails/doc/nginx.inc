
    server {
        listen  80;
        #access_log  /var/logs/nginx/orionet/access.log; #  main;
        server_name  ${HOSTNAME};
        charset koi8-r;

        location /pic/ { root ${ROOT}; }
        location /css/ { root ${ROOT}; }
        location /js/ { root ${ROOT}; }
        location /files/ { root ${ROOT}; }
        location / {
            proxy_pass         http://127.0.0.1:8000/${SYSTEM}/;
            proxy_set_header   Host             $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-URL http://$host:$server_port$request_uri;
        }
   }
