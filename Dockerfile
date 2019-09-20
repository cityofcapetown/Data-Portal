FROM ckan/ckan:latest

MAINTAINER Gordon Inggs, Riaz Arbi, Derek Strong

USER root

# Private Datasets extension
RUN pip install ckanext-privatedatasets

## Resource authorisation extension
RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/etri-odp/ckanext-resourceauthorizer.git

## Custom Schema extension
RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/ckan/ckanext-scheming.git

## Extra security extension
RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/data-govt-nz/ckanext-security.git Beaker==1.6.4

# S3 filestore extension
RUN . /usr/lib/ckan/venv/bin/activate && pip install flask-debugtoolbar boto3 git+https://github.com/keitaroinc/ckanext-s3filestore.git@v0.1.0 
RUN git clone 'https://github.com/okfn/ckanext-s3filestore' /tmp/ckanext-s3filestore && \
    cd /tmp/ckanext-s3filestore && \
    python setup.py install && \
    rm -rf /tmp/ckanext-s3filestore

# datagovsg-s3-resources
#RUN . /usr/lib/ckan/venv/bin/activate && pip install git+https://github.com/datagovsg/ckanext-s3-resources.git slugify boto3 flask-debugtoolbar 

USER ckan
