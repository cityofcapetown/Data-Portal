FROM ckan/ckan:latest

MAINTAINER Gordon Inggs, Riaz Arbi, Derek Strong

USER root

# Private Datasets extension
RUN pip install ckanext-privatedatasets

# Custom Schema extension
RUN git clone 'https://github.com/ckan/ckanext-scheming.git' /tmp/ckanext-scheming && \
  cd /tmp/ckanext-scheming && \
  python setup.py install && \
  rm -rf /tmp/ckanext-scheming

# Extra security extension
RUN pip install Beaker==1.6.4
RUN git clone 'https://github.com/data-govt-nz/ckanext-security.git' /tmp/ckanext-security && \
  cd /tmp/ckanext-security && \
  python setup.py install && \
  rm -rf /tmp/ckanext-security

# Cloud Connector extension
RUN git clone 'https://github.com/DataShades/ckanext-cloudconnector.git' /tmp/ckanext-cloudconnector && \
  cd /tmp/ckanext-cloudconnector && \
  python setup.py install && \
  rm -rf /tmp/ckanext-cloudconnector

USER ckan