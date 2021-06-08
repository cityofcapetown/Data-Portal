#!/usr/bin/env bash
set -e

tmpdir=/tmp
default_aws_bucket=cct-ckan-data
default_aws_access=cctAIOSFODNN7EXAMPLE
default_aws_secret=cctlrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
default_aws_region="us-east-1"
default_aws_host="https://lake.capetown.gov.za"
default_port=8001
default_hostname="http://192.168.2.1:$CKAN_PORT"
default_root_path="data-catalogue"

DATA_DIR=${1:-$tmpdir}
AWS_BUCKET_NAME=${2:-$default_aws_bucket}
AWS_ACCESS_KEY=${3:-$default_aws_access}
AWS_SECRET_KEY=${4:-$default_aws_secret}
AWS_REGION=${5:-$default_aws_region}
AWS_HOST=${6:-$default_aws_host}
CKAN_PORT=${7:-$default_port}
CKAN_HOSTNAME=${8:-$default_hostname}
CKAN_ROOT_PATH=${9:-$default_root_path}

echo Installing everything to "$DATA_DIR"

# Creating network
docker network create -d bridge --subnet=192.168.2.0/24 ckan

# Moving CKAN config across
mkdir -p $DATA_DIR/ckan-config
chmod a+rw -R $DATA_DIR/ckan-config
cp config/*.ini $DATA_DIR/ckan-config/

# Making various directories
mkdir -p $DATA_DIR/solr-data
chmod a+rw -R $DATA_DIR/solr-data

mkdir -p $DATA_DIR/ckan-db-data
chmod a+rw -R $DATA_DIR/ckan-db-data

mkdir -p $DATA_DIR/ckan-datapusher-data
chmod a+rw -R $DATA_DIR/ckan-datapusher-data
cp config/datapusher_settings.py $DATA_DIR/ckan-datapusher-data/

mkdir -p $DATA_DIR/ckan-datastore-db-data
chmod a+rw -R $DATA_DIR/ckan-datastore-db-data

# Making storage location (shouldn't be used)
mkdir -p $DATA_DIR/ckan-storage
chmod a+rw -R $DATA_DIR/ckan-storage

# Updating configuration
CKAN_CONFIG=${DATA_DIR}/ckan-config/production.ini
sed -i "s|AWS_BUCKET_NAME_GOES_HERE|${AWS_BUCKET_NAME}|g" $CKAN_CONFIG
sed -i "s|AWS_ACCESS_KEY_GOES_HERE|${AWS_ACCESS_KEY}|g" $CKAN_CONFIG
sed -i "s|AWS_SECRET_ACCESS_KEY_GOES_HERE|${AWS_SECRET_KEY}|g" $CKAN_CONFIG
sed -i "s|AWS_REGION_NAME_GOES_HERE|${AWS_REGION}|g" $CKAN_CONFIG
sed -i "s|AWS_HOST_NAME_GOES_HERE|${AWS_HOST}|g" $CKAN_CONFIG
sed -i "s|CKAN_ROOT_PATH_GOES_HERE|${CKAN_ROOT_PATH}|g" $CKAN_CONFIG

WHO_CONFIG=${DATA_DIR}/ckan-config/who.ini
sed -i "s|CKAN_ROOT_PATH_GOES_HERE|${CKAN_ROOT_PATH}|g" $WHO_CONFIG

# Creating supporting services
docker run --name ckan-redis --network ckan --restart always -d redis:latest

docker run --name ckan-solr --network ckan --restart always -d -v $DATA_DIR/solr-data:/opt/solr/server/solr/ckan/data ckan/solr

docker run --name ckan-datapusher --network ckan --restart always -d -e SSL_VERIFY=False -p 8800:8800 -v $DATA_DIR/ckan-datapusher-data/datapusher_settings.py:/usr/src/app/deployment/datapusher_settings.py clementmouchet/datapusher

docker run --name db --network ckan --restart always -d -v $DATA_DIR/ckan-db-data:/var/lib/postgresql/data ckan/postgresql

docker run --name ckan-datastore-db --network ckan --restart always -d -v $DATA_DIR/ckan-datastore-db-data:/var/lib/postgresql/data -e DS_RO_PASS=ckan_ro ckan/postgresql


# Setting up CKAN
docker run --name ckan \
	   --network ckan \
     --restart always \
     -d \
     -e CKAN_SQLALCHEMY_URL=postgresql://ckan:ckan@db/ckan \
     -e CKAN_DATASTORE_WRITE_URL=postgresql://ckan:ckan@ckan-datastore-db/datastore \
     -e CKAN_DATASTORE_READ_URL=postgresql://datastore_ro:ckan_ro@ckan-datastore-db/datastore \
	   -e CKAN_DATAPUSHER_URL=http://ckan-datapusher:8800 \
	   -e CKAN_DATAPUSHER_CALLBACK_URL_BASE=http://ckan:5000/ \
	   -e CKAN_SOLR_URL=http://ckan-solr:8983/solr/ckan \
     -e CKAN_REDIS_URL=redis://ckan-redis:6379/1 \
	   -e CKAN_SITE_URL=$CKAN_HOSTNAME \
	   -e CKAN_PORT=$CKAN_PORT \
     -e POSTGRES_PASSWORD=ckan \
     -e DS_RO_PASS=ckan_ro \
     -v $DATA_DIR/ckan-config:/etc/ckan \
	   -v $DATA_DIR/ckan-storage:/var/lib/ckan \
	   -p $CKAN_PORT:5000 \
	   -it \
	   cityofcapetown/data-portal@sha256:4076055d86ae2c5d010737ef57ee9844ff084801ec06d9612e5a190fd7a4d0e7

# Giving things a chance to start up
sleep 10

# Setting permissions
docker exec ckan ckan --config /etc/ckan/production.ini datastore set-permissions | \
  docker exec -i ckan-datastore-db psql -U ckan

# Creating an admin user
docker exec -it ckan ckan --config /etc/ckan/production.ini sysadmin add ckan_admin
