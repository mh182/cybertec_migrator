#!/usr/bin/env bash

VERSION=v3.9.0
POD_NAME=migrator
CORE_DB_PASSWORD=${CORE_DB_PASSWORD:-postgres}

echo "Cleaning up exiting containers"
podman pod stop ${POD_NAME} && podman pod rm ${POD_NAME}

# For now lets expose internal ports
podman pod create --name migrator -p 5432:5432 -p 3000:3000
echo "Created pod '${POD_NAME}'"

# This will create a volume container called 'core_db-data'
# TODO: Why we need :Z option for the read-only file 'initdb.sh'? If ommitted the file is not mounted into the container
echo "Starting core_db"
podman run -d --pod ${POD_NAME} --name core_db \
    -v ./docker/initdb.sh:/docker-entrypoint-initdb.d/init-user-db.sh:Z \
    -v core_db-data:/var/lib/postgresql/data:Z \
    -e POSTGRES_PASSWORD=${CORE_DB_PASSWORD} \
    docker.io/postgres:13-alpine

echo "Waiting until database is up"
sleep 5

echo "Starting core"
podman run -d --pod ${POD_NAME} --name core \
    -e CORE_DB_HOST=localhost \
    -e CORE_DB_PASSWORD=${CORE_DB_PASSWORD} \
    -e CORE_DB_DATABASE=migrator \
    docker.io/cybertecpostgresql/cybertec_migrator-core:${VERSION}
