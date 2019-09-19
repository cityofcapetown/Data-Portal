#!/usr/bin/env bash

# Creating network
docker network create -d bridge ckan

# Creating supporting services
docker run --name ckan-redis --network ckan --rm -d redis:latest

docker run --name ckan-solr --network ckan --restart always -d -v /tmp/solr-data:/opt/solr/server/solr/ckan/data ckan/solr

docker run --name ckan-datapusher --network ckan --restart always -d -p 8800:8800 clementmouchet/datapusher

docker run --name db --network ckan --restart always -d -v /tmp/ckan-postgresql-data:/var/lib/postgresql/data -e DS_RO_PASS=ckan_ro ckan/postgresql

docker run --name ckan-minio --network ckan --restart always -d -p 9000:9000 -e "MINIO_ACCESS_KEY=cctAIOSFODNN7EXAMPLE" -e "MINIO_SECRET_KEY=cctlrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" minio/minio server /tmp/ckan-minio_data

# Moving config across
mkdir -p /tmp/ckan-config
chmod a+rw -R /tmp/ckan-config
cp config/*.ini /tmp/ckan-config/

# Making storage location
mkdir -p /tmp/ckan-storage
chmod a+rw -R /tmp/ckan-storage

# Setting up CKAN
docker run --name ckan \
	   --network ckan \
           --restart always \
           -d \
           -e CKAN_SQLALCHEMY_URL=postgresql://ckan:ckan@db/ckan \
           -e CKAN_DATASTORE_WRITE_URL=postgresql://ckan:ckan@db/datastore \
           -e CKAN_DATASTORE_READ_URL=postgresql://datastore_ro:datastore@db/datastore \
	   -e CKAN_DATAPUSHER_URL=http://ckan-datapusher:8800 \
	   -e CKAN_SOLR_URL=http://ckan-solr:8983/solr/ckan \
           -e CKAN_REDIS_URL=redis://ckan-redis:6379/1 \
	   -e CKAN_SITE_URL=http://$(hostname):8001 \
	   -e CKAN_PORT=8001 \
           -e POSTGRES_PASSWORD=ckan \
           -e DS_RO_PASS=datastore \
           -v /tmp/ckan-config:/etc/ckan \
	   -v /tmp/ckan-storage:/var/lib/ckan \
	   -p 8001:5000 \
	   -it \
	   cityofcapetown/data-portal

# Setting permissions
docker exec ckan /usr/local/bin/ckan-paster --plugin=ckan datastore set-permissions -c /etc/ckan/production.ini | docker exec -i db psql -U ckan

