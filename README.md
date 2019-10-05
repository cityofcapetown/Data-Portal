# Data-Portal
Docker image for City's data portal prototype.

## Setting up
Drawing heavily on [these instructions](https://docs.ckan.org/en/2.8/maintaining/installing/install-from-docker-compose.html), as well as the accompanying [docker compose file](https://github.com/ckan/ckan/blob/master/contrib/docker/docker-compose.yml).

Also, the work done by OpenUp on [SA's National Treasury CKAN](https://github.com/vulekamali/treasury-ckan).

**NB** The below config is strictly for development purposes, and is horribly insecure.

1. Run the script `bash bin/run_ckan.sh` 
2. Copy across the config files into the CKAN config directory specified in the run script
3. Create an admin user: `docker exec -it ckan /usr/local/bin/ckan-paster --plugin=ckan sysadmin -c /etc/ckan/production.ini add ckan_admin`
4. CKAN should be accessible at <hostname>:8001
5. Remove everything: `bash bin/rm_ckan.sh`

## Customising for Production
Working notes on what has to be done to prepare this install for production deployment:
* Change location of all mounted volumes to somewhere other than `/tmp`.
* Change Access and Secret key for Minio when spinning up container, and also in the CKAN config file.
* Setup an Nginx SSL/TLS termination point:
  * ~~generate self-signed SSL/TLS cert (`openssl req -x509 -newkey rsa:4096 -keyout ckan_key.pem -out ckan_cert.pem -days 3650 -nodes`).~~
  * use [certbot](https://certbot.eff.org/lets-encrypt) to generate properly signed certificates for our subdomains (you'll need to register these somehow): 
    * `sudo certbot certonly --standalone -d <FQDN e.g. data.demo.com>`
    * Creates certificate at `/etc/letsencrypt/live/<FQDN>/cert.pem`
    * Creates key at `/etc/letsencrypt/live/<FQDN>/privkey.pem` 
  * Set up NGINX config with proxy rules to pass traffic from port `443` to port `5000` (the one that CKAN is on). See config directory for example config.
  * Create the NGINX reverse proxy: `docker run -d --restart always -v <path to letsencrypt certs e.g. /etc/letsencrypt>:/etc/nginx/certs:z -v <Path to NGINX config>:/etc/nginx/conf.d/default.conf --network ckan --name ckan-proxy -p 443:443 -p 80:80 nginx`
