# mapserver nginx docker

A smallish image with mapserver via fastcgi and nginx, to be used with mapfile alias in ms config

## Build

docker build -t pvgenuchten/mapserver_nginx_docker

## Run

docker run -p 8080:80 ghcr.io/pvgenuchten/mapserver_nginx_docker

## Config

- Mount the data folder and the ms config file to /maps.
- In mounted config file add alias for each mapfile.

## Test

http://localhost:8080 -> opens the mapserver homepage, listing all mapfiles

