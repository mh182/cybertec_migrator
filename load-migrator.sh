#!/usr/bin/env bash

# Development images
VERSION=pr-625
CONTAINER_REGISTRY=ghcr.io/cybertec-postgresql

# Offcial releases
# VERSION=v3.9.0
# CONTAINER_REGISTRY=docker.io/cybertecpostgresql

POD_NAME=migrator
CORE_DB_PASSWORD=${CORE_DB_PASSWORD:-postgres}
EXTERNAL_HTTP_PORT=8080

echo "Cleaning up exiting containers"
podman pod stop ${POD_NAME} && podman pod rm ${POD_NAME}
podman volume rm core_db-data

# TODO: For now lets expose internal ports
echo -n "Create pod [${POD_NAME}]: "
podman pod create --name migrator -p ${EXTERNAL_HTTP_PORT}:80 \
    -p 5432:5432 -p 3000:3000

# This will create a volume container called 'core_db-data'
# TODO: Why we need :Z option for the read-only file 'initdb.sh'? If ommitted the file is not mounted into the container
echo -n "Starting [core_db]: "
podman run -d --pod ${POD_NAME} --name core_db \
    -v ./docker/initdb.sh:/docker-entrypoint-initdb.d/init-user-db.sh:Z \
    -v core_db-data:/var/lib/postgresql/data:Z \
    -e POSTGRES_PASSWORD=${CORE_DB_PASSWORD} \
    docker.io/postgres:13-alpine

echo -n "Starting [core]: "
podman run -d --pod ${POD_NAME} --name core \
    -e CORE_DB_HOST=localhost \
    -e CORE_DB_PASSWORD=${CORE_DB_PASSWORD} \
    -e CORE_DB_DATABASE=migrator \
    ${CONTAINER_REGISTRY}/cybertec_migrator-core:${VERSION-latest}

echo -n "Starting [web_gui]: "
podman run -d --pod ${POD_NAME} --name web_gui \
    -v ./docker/templates:/etc/nginx/templates:Z \
    -e CORE_DB_DATABASE=migrator \
    ${CONTAINER_REGISTRY}/cybertec_migrator-web_gui:${VERSION-latest}
