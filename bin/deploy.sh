#!/usr/bin/env bash

set -e

# Create CKAN namespace
kubectl create namespace "ckan"

# Create config maps for various services
kubectl create configmap datapusher-settings-py --namespace ckan --from-file=config/datapusher_settings.py
kubectl create configmap production-ini --namespace ckan --from-file=config/production.ini
kubectl create configmap who-ini --namespace ckan --from-file=config/who.ini

# Creating secrets
default_postgres_password="ckan"
POSTGRES_PASSWORD=${1:-$default_postgres_password}
default_datastore_ro_password="ckan_ro"
DATASTORE_RO_PASSWORD=${2:-$default_datastore_ro_password}

default_minio_access=cctAIOSFODNN7EXAMPLE
MINIO_ACCESS_KEY=${3:-$default_minio_access}
default_minio_secret=cctlrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
MINIO_SECRET_KEY=${4:-$default_minio_secret}

# These will be passed in as env variables to the CKAN frontend
kubectl create secret generic ckan-secret  --namespace ckan \
	--from-literal="CKAN_SQLALCHEMY_URL"="postgresql://ckan:$POSTGRES_PASSWORD@db/ckan" \
	--from-literal="CKAN_DATASTORE_WRITE_URL"="postgresql://ckan:$POSTGRES_PASSWORD@ckan-datastore-db/datastore" \
	--from-literal="CKAN_DATASTORE_READ_URL"="postgresql://datastore_ro:$DATASTORE_RO_PASSWORD@ckan-datastore-db/datastore" \
	--from-literal="POSTGRES_PASSWORD"="$POSTGRES_PASSWORD" \
	--from-literal="DS_RO_PASS"="$DATASTORE_RO_PASSWORD" \
	--from-literal="CKAN___CKANEXT__S3FILESTORE__AWS_ACCESS_KEY_ID"="$MINIO_ACCESS_KEY" \
	--from-literal="CKAN___CKANEXT__S3FILESTORE__AWS_SECRET_ACCESS_KEY"="$MINIO_SECRET_KEY"

# Creating persistent pods
kubectl apply -f config/k8s/ckan-persistent.yaml

# Waiting for db and datastore pods to be up
datastore_pod=$(kubectl get pod --namespace ckan | grep ckan-datastore-db | cut -d " " -f1)
db_pod=$(kubectl get pod --namespace ckan | grep ckan-db | cut -d " " -f1)
while [[ $(kubectl get pods "$datastore_pod" --namespace ckan -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for temporary pod" && sleep 1; done
while [[ $(kubectl get pods "$db_pod" --namespace ckan -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for temporary pod" && sleep 1; done

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
	-- /usr/local/bin/ckan-paster --plugin=ckan datastore set-permissions -c /etc/ckan/production.ini \
	| kubectl exec "$datastore_pod" -i -c ckan-datastore-db --namespace ckan \
	-- psql -U ckan

# Generate collaborator DB tables
kubectl exec "$ckan_permission_pod" -c ckan-permission-setup --namespace ckan \
	-- /usr/local/bin/ckan-paster --plugin=ckanext-collaborators collaborators init-db -c /etc/ckan/production.ini

# Cleaning up permissions pod
kubectl delete -f config/k8s/ckan-permission.yaml

# Creating frontend pods
kubectl apply -f config/k8s/ckan-frontend.yaml

# Rebuilding Solr Index (just in-case)
frontend_pod=$(kubectl get pod --namespace ckan | grep ckan-frontend | cut -d " " -f1)
kubectl exec "$frontend_pod" -c ckan-frontend -i --namespace ckan \
	-- /usr/local/bin/ckan-paster --plugin=ckan search-index rebuild --config=/etc/ckan/production.ini

# Creating Sysadmin user
# *Warning* interactive and echos password to screen
frontend_pod=$(kubectl get pod --namespace ckan | grep ckan-frontend | cut -d " " -f1)
kubectl exec "$frontend_pod" -c ckan-frontend -it --namespace ckan \
	-- /usr/local/bin/ckan-paster --plugin=ckan sysadmin add ckan_admin email=gordon.inggs@capetown.gov.za name=ckan_admin -c /etc/ckan/production.ini
