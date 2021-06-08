#!/usr/bin/env bash
set -e

tmpdir=/tmp
default_http_ingress_port="80"
default_https_ingress_port="443"
default_hostname="cctdata.co.za"
default_root_path="data-catalogue"

DATA_DIR=${1:-$tmpdir}
HTTP_INGRESS_PORT=${2:-$default_http_ingress_port}
HTTPS_INGRESS_PORT=${3:-$default_https_ingress_port}
CKAN_HOSTNAME=${4:-$default_hostname}
CKAN_ROOT_PATH=${5:-$default_root_path}

# Moving CKAN config across
mkdir -p $DATA_DIR/ckan-proxy-config
chmod a+rw -R $DATA_DIR/ckan-proxy-test-config
cp config/nginx_config_test.conf $DATA_DIR/ckan-proxy-test-config/

# Replacing config values
NGINX_CONFIG=$DATA_DIR/ckan-proxy-config/nginx_config.conf
sed -i "s|CKAN_HOSTNAME_GOES_HERE|${CKAN_ROOT_PATH}|g" $NGINX_CONFIG
sed -i "s|CKAN_ROOT_PATH_GOES_HERE|${CKAN_ROOT_PATH}|g" $NGINX_CONFIG

# Setting up SSL cert
sudo certbot certonly --standalone -d $CKAN_HOSTNAME

# Go, go, go!
docker run -d --restart always \
               -v $DATA_DIR/ckan-proxy-config/nginx_config.conf:/etc/nginx/conf.d/default.conf \
               -v /etc/letsencrypt:/etc/nginx/certs:z \
               --network ckan \
               --name ckan-proxy \
               -p $HTTP_INGRESS_PORT:80 -p $HTTPS_INGRESS_PORT:443 \
               nginx