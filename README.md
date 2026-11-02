# mapserver nginx docker

A smallish image with mapserver via fastcgi and nginx, to be used with mapfile alias in ms config

## Build

docker build -t mapserver/nginx

## Run

docker run -p 8080:80 mapserver/nginx

Mount the data folder and the ms config file to /maps
