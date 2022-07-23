FROM debian:stretch
MAINTAINER Gordon Inggs, Riaz Arbi, Derek Strong
# With thanks to the main CKAN dockerfile - https://github.com/ckan/ckan/blob/ckan-2.8.3/Dockerfile

# Install required system packages
RUN apt-get -q -y update \
    && DEBIAN_FRONTEND=noninteractive apt-get -q -y upgrade \
    && apt-get -q -y install \
        python-dev \
        python-pip \
        python-virtualenv \
        python-wheel \
        python3-dev \
        python3-pip \
        python3-virtualenv \
        python3-wheel \
        libpq-dev \
        libxml2-dev \
        libxslt-dev \
        libgeos-dev \
        libssl-dev \
        libffi-dev \
        postgresql-client \
        build-essential \
        git-core \
        vim \
        wget \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*

# Define environment variables
ENV CKAN_HOME /usr/lib/ckan
ENV CKAN_VENV $CKAN_HOME/venv
ENV CKAN_CONFIG /etc/ckan
ENV CKAN_STORAGE_PATH=/var/lib/ckan

# Create ckan user
RUN useradd -r -u 900 -m -c "ckan account" -d $CKAN_HOME -s /bin/false ckan

# Setup virtual environment for CKAN
RUN mkdir -p $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH && \
    virtualenv $CKAN_VENV && \
    ln -s $CKAN_VENV/bin/pip /usr/local/bin/ckan-pip && \
    ln -s $CKAN_VENV/bin/paster /usr/local/bin/ckan-paster && \
    ln -s $CKAN_VENV/bin/ckan /usr/local/bin/ckan

# Setup CKAN
RUN git clone https://github.com/ckan/ckan.git $CKAN_VENV/src/ckan/
# Locking the version to 2.9.2
RUN cd $CKAN_VENV/src/ckan/ && git checkout tags/ckan-2.9.2
RUN ckan-pip install -U pip && \
    ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirement-setuptools.txt && \
    ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirements-py2.txt && \
    ckan-pip install -e $CKAN_VENV/src/ckan/ && \
    ln -s $CKAN_VENV/src/ckan/ckan/config/who.ini $CKAN_CONFIG/who.ini && \
    chown -R ckan:ckan $CKAN_HOME $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH

# Setting up extensions
## S3 filestore extension
RUN ckan-pip install -r https://raw.githubusercontent.com/qld-gov-au/ckanext-s3filestore/0.6.1-qgov/requirements.txt && \
    ckan-pip install git+https://github.com/qld-gov-au/ckanext-s3filestore@0.7.7-qgov.2

## Hierarchy extension
RUN ckan-pip install -r https://raw.githubusercontent.com/ckan/ckanext-hierarchy/1dda3fd65d57759276eb18ae63c7c9fd73e0c5f5/requirements.txt && \
    ckan-pip install git+https://github.com/ckan/ckanext-hierarchy@1dda3fd65d57759276eb18ae63c7c9fd73e0c5f5

## Custom Schema extension
RUN ckan-pip install -r https://raw.githubusercontent.com/ckan/ckanext-scheming/release-1.2.0/requirements.txt && \
    ckan-pip install git+https://github.com/ckan/ckanext-scheming.git@release-1.2.0

## CCT Metadata
RUN ckan-pip install -r https://raw.githubusercontent.com/cityofcapetown/ckanext-cct_metadata/wip/v0.2/requirements.txt && \
    ckan-pip install git+https://github.com/cityofcapetown/ckanext-cct_metadata.git@wip/v0.2

# And back to getting things up
COPY bin/ckan-entrypoint.sh /ckan-entrypoint.sh
RUN chmod +x /ckan-entrypoint.sh
ENTRYPOINT ["/ckan-entrypoint.sh"]

USER ckan
EXPOSE 5000

CMD ["ckan","-c","/etc/ckan/production.ini", "run", "--host", "0.0.0.0"]
