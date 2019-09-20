FROM ckan/ckan:latest

MAINTAINER Gordon Inggs, Riaz Arbi, Derek Strong

USER root

# Locking CKAN version to 2.7.6
RUN . /usr/lib/ckan/venv/bin/activate && \
    git clone -b ckan-2.7.6 --single-branch --depth 1 'https://github.com/ckan/ckan.git' /tmp/ckan && \
    cd /tmp/ckan && \
    python setup.py install && \
    cd - && rm -rf /tmp/ckan

# Private Datasets extension
RUN pip install ckanext-privatedatasets

## Resource authorisation extension
RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/etri-odp/ckanext-resourceauthorizer.git

## Custom Schema extension
RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/ckan/ckanext-scheming.git

## Extra security extension
RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/data-govt-nz/ckanext-security.git Beaker==1.6.4

# S3 filestore extension
RUN . /usr/lib/ckan/venv/bin/activate && \ 
    git clone -b v0.1.1 --single-branch --depth 1 'https://github.com/okfn/ckanext-s3filestore' /tmp/ckanext-s3filestore && \
    cd /tmp/ckanext-s3filestore && \
    pip install -r requirements.txt && \
    python setup.py install && \
    rm -rf /tmp/ckanext-s3filestore

# datagovsg-s3-resources
#RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/datagovsg/ckanext-s3-resources.git slugify boto3 flask-debugtoolbar 

USER ckan
