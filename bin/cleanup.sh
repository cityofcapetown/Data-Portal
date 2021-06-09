#!/usr/bin/env bash

kubectl delete -f config/k8s/ckan-frontend.yaml
kubectl delete -f config/k8s/ckan-permission.yaml
kubectl delete -f config/k8s/ckan-persistent.yaml
kubectl delete secret -n ckan ckan-secret
kubectl delete configmap -n ckan who-ini production-ini datapusher-settings-py
kubectl delete namespace ckan
