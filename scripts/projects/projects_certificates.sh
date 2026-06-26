#!/bin/bash

source .env

PROJECTS="${PROJECTS_LARAVEL} ${PROJECTS_SYMFONY}"

sudo apt install libnss3-tools mkcert
mkcert -install
mkcert -key-file $PATH_CERTIFICATES/server.key -cert-file $PATH_CERTIFICATES/server.crt $PROJECTS

docker cp $PATH_CERTIFICATES/server.key $CONTAINER_PHP:/usr/local/share/ca-certificates/server.key