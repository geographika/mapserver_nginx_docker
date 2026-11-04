# Mapserver NGINX Docker

A Ubuntu+NGINX based docker image for mapserver via fastcgi.
Prepared for using a mapfile alias in mapserver config file.

## Features

- Call your maps as http://{server}/{alias}?service=wms&request=getcapabilities
- Includes microsoft core fonts, reference fontset at '/etc/mapserver/fonts.txt'
- Includes a robots.txt and favicon.ico
- Ihe default image includes a default map, called countries
- Mapserver index page and OGCAPI pre configured on the default map
- CORS headers enabled

## Build

```
docker build -t pvgenuchten/mapserver_nginx_docker
```

## Run

```
docker run -p 8080:80 ghcr.io/pvgenuchten/mapserver_nginx_docker
```

Navigate to <http://localhost:8080>

## Config

- Mount the data folder and the ms config file to /maps.
- In mounted config file add alias for each mapfile.

## Test

Use [wms-tester](https://github.com/pvgenuchten/wms-tester) to test your image

