FROM ckan/ckan:latest

MAINTAINER Gordon Inggs, Riaz Arbi, Derek Strong

USER root

# Private Datasets extension
RUN . /usr/lib/ckan/venv/bin/activate && pip install ckanext-privatedatasets

## Resource authorisation extension
RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/etri-odp/ckanext-resourceauthorizer.git

## Custom Schema extension
RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/ckan/ckanext-scheming.git

## Extra security extension
RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/data-govt-nz/ckanext-security.git Beaker==1.6.4

# S3 filestore extension
RUN . /usr/lib/ckan/venv/bin/activate && \
    pip install git+https://github.com/okfn/ckanext-s3filestore@v0.1.1 boto3>=1.4.4 ckantoolkit

# datagovsg-s3-resources
#RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/datagovsg/ckanext-s3-resources.git slugify boto3 flask-debugtoolbar 

USER ckan
