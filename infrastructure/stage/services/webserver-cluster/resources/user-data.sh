#!/bin/bash
echo "Hello, World" > index.html
nohup bash -c "python3 -m http.server ${server_http_port}" &
