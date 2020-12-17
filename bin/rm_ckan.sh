#!/usr/bin/env bash

docker rm -f ckan-redis
docker rm -f ckan-solr
docker rm -f ckan-datapusher
docker rm -f db
docker rm -f ckan-datastore-db
docker rm -f ckan

docker network rm ckan

#sudo rm -rf /tmp/ckan-config
#sudo rm -rf /tmp/ckan-storage
