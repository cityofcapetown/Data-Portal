#!/usr/bin/env bash

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

# Temporary setup pod
# Mostly for setting datastore permissions
kubectl apply -f config/k8s/ckan-permission.yaml
datastore_pod=$(kubectl get pod --namespace ckan | grep ckan-datastore-db | cut -d " " -f1)

while [[ $(kubectl get pods ckan-datastore --namespace ckan -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for temporary pod" && sleep 1; done
while [[ $(kubectl get pods ckan-db --namespace ckan -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for temporary pod" && sleep 1; done
while [[ $(kubectl get pods ckan-permission-setup --namespace ckan -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for temporary pod" && sleep 1; done

kubectl exec ckan-permission-setup -c ckan-permission-setup --namespace ckan \ 
	-- /usr/local/bin/ckan-paster --plugin=ckan datastore set-permissions -c /etc/ckan/production.ini \
	| kubectl exec "$datastore_pod" -i -c ckan-datastore-db --namespace ckan \
	-- psql -U ckan
kubectl delete -f config/k8s/ckan-permission.yaml

# Creating frontend pods
kubectl apply -f config/k8s/ckan-frontend.yaml

# Rebuilding Solr Index (just in-case)
frontend_pod=$(kubectl get pod --namespace ckan | grep ckan-frontend | cut -d " " -f1)
kubectl exec "$frontend_pod" -c ckan-frontend -i --namespace ckan \
	-- /usr/local/bin/ckan-paster --plugin=ckan search-index rebuild --config=/etc/ckan/production.ini

