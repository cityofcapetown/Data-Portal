#!/usr/bin/env bash

docker rm -f ckan-redis
docker rm -f ckan-solr
docker rm -f ckan-datapusher
docker rm -f db
docker rm -f ckan-datastore-db
docker rm -f ckan
docker rm -f ckan-proxy

docker network rm ckan
