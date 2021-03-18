#!/usr/bin/env bash
set -e

tmpdir=/tmp
default_ingress_port="8002"
default_root_path="data-catalogue"

DATA_DIR=${1:-$tmpdir}
INGRESS_PORT=${2:-$default_ingress_port}
CKAN_ROOT_PATH=${3:-$default_root_path}

# Moving CKAN config across
mkdir -p $DATA_DIR/ckan-proxy-test-config
chmod a+rw -R $DATA_DIR/ckan-proxy-test-config
cp config/nginx_config_test.conf $DATA_DIR/ckan-proxy-test-config/

# REPLACING CONFIG VALUES
NGINX_CONFIG=$DATA_DIR/ckan-proxy-test-config/nginx_config_test.conf
sed -i "s|CKAN_ROOT_PATH_GOES_HERE|${CKAN_ROOT_PATH}|g" $NGINX_CONFIG

# Running
docker run -d --restart always \
               -v $DATA_DIR/ckan-proxy-test-config/nginx_config_test.conf:/etc/nginx/conf.d/default.conf \
               --network ckan \
               --name ckan-proxy \
               -p $INGRESS_PORT:80 \
               nginx