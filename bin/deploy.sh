#!/usr/bin/env bash

set -e

# Script Args
tmpdir=/tmp
default_aws_bucket=ckan-test.data
default_aws_access=ckan-test
default_aws_secret=ckan-test
default_aws_region="us-east-1"
default_aws_host="https://lake.capetown.gov.za"
default_port=8001
default_hostname="http://datascience.capetown.gov.za"
default_root_path="ckan-test"
default_postgres_password="ckan"
default_datastore_ro_password="ckan_ro"

AWS_BUCKET_NAME=${1:-$default_aws_bucket}
AWS_ACCESS_KEY=${2:-$default_aws_access}
AWS_SECRET_KEY=${3:-$default_aws_secret}
AWS_REGION=${4:-$default_aws_region}
AWS_HOST=${5:-$default_aws_host}
CKAN_PORT=${6:-$default_port}
CKAN_HOSTNAME=${7:-$default_hostname}
CKAN_ROOT_PATH=${8:-$default_root_path}
POSTGRES_PASSWORD=${9:-$default_postgres_password}
DATASTORE_RO_PASSWORD=${10:-$default_datastore_ro_password}

# Create CKAN namespace
kubectl get namespace ckan || kubectl create namespace ckan

# Create config maps for various services
cp config/production.ini ${tmpdir}/
cp config/who.ini ${tmpdir}/

# Updating configuration
CKAN_CONFIG=${tmpdir}/production.ini
sed -i "s|AWS_BUCKET_NAME_GOES_HERE|${AWS_BUCKET_NAME}|g" $CKAN_CONFIG
sed -i "s|AWS_ACCESS_KEY_GOES_HERE|${AWS_ACCESS_KEY}|g" $CKAN_CONFIG
sed -i "s|AWS_SECRET_ACCESS_KEY_GOES_HERE|${AWS_SECRET_KEY}|g" $CKAN_CONFIG
sed -i "s|AWS_REGION_NAME_GOES_HERE|${AWS_REGION}|g" $CKAN_CONFIG
sed -i "s|AWS_HOST_NAME_GOES_HERE|${AWS_HOST}|g" $CKAN_CONFIG
sed -i "s|CKAN_ROOT_PATH_GOES_HERE|${CKAN_ROOT_PATH}|g" $CKAN_CONFIG

WHO_CONFIG=${tmpdir}/who.ini
sed -i "s|CKAN_ROOT_PATH_GOES_HERE|${CKAN_ROOT_PATH}|g" $WHO_CONFIG

# Deploying configurations
kubectl get configmap -n ckan datapusher-settings-py || \
  kubectl create configmap datapusher-settings-py --namespace ckan --from-file=config/datapusher_settings.py

kubectl create configmap datapusher-settings-py --namespace ckan --from-file=config/datapusher_settings.py -o yaml --dry-run | \
  kubectl replace -f -

kubectl get configmap -n ckan production-ini || \
  kubectl create configmap production-ini --namespace ckan --from-file=${CKAN_CONFIG}

kubectl create configmap production-ini --namespace ckan --from-file=${CKAN_CONFIG} -o yaml --dry-run | \
  kubectl replace -f -

kubectl get configmap -n ckan who-ini || \
  kubectl create configmap who-ini --namespace ckan --from-file=${WHO_CONFIG}

kubectl create configmap who-ini --namespace ckan --from-file=${WHO_CONFIG} -o yaml --dry-run | \
  kubectl replace -f -

# Creating secrets
# These will be passed in as env variables to the CKAN frontend
kubectl get secret -n ckan ckan-secret || \
  kubectl create secret generic ckan-secret  --namespace ckan \
    --from-literal="CKAN_SQLALCHEMY_URL"="postgresql://ckan:$POSTGRES_PASSWORD@db/ckan" \
    --from-literal="CKAN_DATASTORE_WRITE_URL"="postgresql://ckan:$POSTGRES_PASSWORD@ckan-datastore-db/datastore" \
    --from-literal="CKAN_DATASTORE_READ_URL"="postgresql://datastore_ro:$DATASTORE_RO_PASSWORD@ckan-datastore-db/datastore" \
    --from-literal="POSTGRES_PASSWORD"="$POSTGRES_PASSWORD" \
    --from-literal="DS_RO_PASS"="$DATASTORE_RO_PASSWORD"

kubectl create secret generic ckan-secret  --namespace ckan \
    --from-literal="CKAN_SQLALCHEMY_URL"="postgresql://ckan:$POSTGRES_PASSWORD@db/ckan" \
    --from-literal="CKAN_DATASTORE_WRITE_URL"="postgresql://ckan:$POSTGRES_PASSWORD@ckan-datastore-db/datastore" \
    --from-literal="CKAN_DATASTORE_READ_URL"="postgresql://datastore_ro:$DATASTORE_RO_PASSWORD@ckan-datastore-db/datastore" \
    --from-literal="POSTGRES_PASSWORD"="$POSTGRES_PASSWORD" \
    --from-literal="DS_RO_PASS"="$DATASTORE_RO_PASSWORD" -o yaml --dry-run | \
  kubectl replace -f -

# Creating persistent pods
kubectl apply -f config/k8s/ckan-persistent.yaml

# Waiting for db and datastore pods to be up
sleep 1
datastore_pod=$(kubectl get pod --namespace ckan | grep ckan-datastore-db | cut -d " " -f1)
db_pod=$(kubectl get pod --namespace ckan | grep ckan-db | cut -d " " -f1)
while [[ $(kubectl get pods "$datastore_pod" --namespace ckan -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for datastore pod" && sleep 1; done
while [[ $(kubectl get pods "$db_pod" --namespace ckan -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for DB pod" && sleep 1; done

# Giving it 10 seconds to come up
echo "Giving datastore and db pods a chance to start up"
sleep 20

# Correcting password setting for datastore
kubectl exec "$datastore_pod" -i -c ckan-datastore-db --namespace ckan \
	-- psql -U ckan -c "ALTER USER datastore_ro WITH PASSWORD '$DATASTORE_RO_PASSWORD';"

# Temporary setup pod
# Mostly for setting datastore permissions
kubectl apply -f config/k8s/ckan-permission.yaml

# Waiting for permission pod to come up
ckan_permission_pod=$(kubectl get pod --namespace ckan | grep ckan-permission-setup | cut -d " " -f1)
while [[ $(kubectl get pods "$ckan_permission_pod" --namespace ckan -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for temporary pod" && sleep 1; done

# Configuring CKAN DB permissions - fairly awkward, we generate SQL in CKAN and pass it to the datastore DB
kubectl exec "$ckan_permission_pod" -c ckan-permission-setup --namespace ckan \
	-- ckan --config /etc/ckan/production.ini datastore set-permissions \
	| kubectl exec "$datastore_pod" -i -c ckan-datastore-db --namespace ckan \
	-- psql -U ckan

# Cleaning up permissions pod
kubectl delete -f config/k8s/ckan-permission.yaml

# Creating frontend pods
kubectl apply -f config/k8s/ckan-frontend.yaml

# Rebuilding Solr Index (just in-case)
frontend_pod=$(kubectl get pod --namespace ckan | grep ckan-frontend | cut -d " " -f1)
while [[ $(kubectl get pods "$frontend_pod" --namespace ckan -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
  echo "waiting for frontend ckan pod" && sleep 1;
done
solr_pod=$(kubectl get pod --namespace ckan | grep ckan-solr | cut -d " " -f1)
while [[ $(kubectl get pods "$solr_pod" --namespace ckan -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
  echo "waiting for ckan solr pod" && sleep 1;
done

echo "Giving solr some time to start up"
sleep 300
kubectl exec "$frontend_pod" -c ckan-frontend -i --namespace ckan \
	-- ckan --config /etc/ckan/production.ini search-index rebuild

# Creating Sysadmin user
# *Warning* interactive and echos password to screen
kubectl exec "$frontend_pod" -c ckan-frontend -it --namespace ckan \
	-- ckan --config /etc/ckan/production.ini sysadmin add ckan_admin

# Cleaning up config files
echo "Waiting 30 seconds before cleaning up config files"
sleep 30
rm ${CKAN_CONFIG} ${WHO_CONFIG}
