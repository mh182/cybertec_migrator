#!/usr/bin/env bash

CORE_DB_PASSWORD=${CORE_DB_PASSWORD:-postgres}
VERSION=v3.9.0

echo "Cleaning up exiting containers"
podman stop core && podman rm core
podman stop core_db && podman rm core_db

# This will create a volume container called 'core_db-data'
# TODO: Why we need :Z option for the read-only file 'initdb.sh'? If ommitted the file is not mounted into the container
podman run -d --name core_db -p 5432:5432 \
    -v ./docker/initdb.sh:/docker-entrypoint-initdb.d/init-user-db.sh:Z \
    -v core_db-data:/var/lib/postgresql/data:Z \
    -e POSTGRES_PASSWORD=${CORE_DB_PASSWORD} \
    docker.io/postgres:13-alpine

echo "Waiting until database is up"
sleep 5

podman run -d --name core -p 3000:3000\
    -e CORE_DB_HOST=core_db \
    -e CORE_DB_PASSWORD=${CORE_DB_PASSWORD} \
    -e CORE_DB_DATABASE=migrator \
    docker.io/cybertecpostgresql/cybertec_migrator-core:${VERSION}
