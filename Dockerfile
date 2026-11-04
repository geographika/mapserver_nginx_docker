
# syntax=docker/dockerfile:1.7

# ============================================================
# Stage 1: Build MapServer
# ============================================================
FROM debian:trixie-slim AS builder

ARG MAPSERVER_VERSION=8.6.6

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ca-certificates \
    curl \
    pkg-config \
    libfcgi-dev \
    libgdal-dev \
    libproj-dev \
    libgeos-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype-dev \
    libtiff-dev \
    libpq-dev \
    libcairo2-dev \
    libfribidi-dev \
    libharfbuzz-dev \
    libgif-dev \
    libsqlite3-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN curl -fSL \
    "https://download.osgeo.org/mapserver/mapserver-${MAPSERVER_VERSION}.tar.gz" \
    -o mapserver.tar.gz \
    && mkdir mapserver \
    && tar -xzf mapserver.tar.gz \
        --strip-components=1 \
        -C mapserver \
    && rm mapserver.tar.gz

WORKDIR /build/mapserver/build

RUN cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DWITH_FCGI=ON \
    -DWITH_CGI=ON \
    -DWITH_GDAL=ON \
    -DWITH_OGR=ON \
    -DWITH_PROJ=ON \
    -DWITH_GEOS=ON \
    -DWITH_POSTGIS=ON \
    -DWITH_WMS=ON \
    -DWITH_WFS=ON \
    -DWITH_PROTOBUFC=OFF \
    -DWITH_CAIRO=ON \
    -DWITH_FRIBIDI=ON \
    -DWITH_HARFBUZZ=ON \
    && cmake --build . --parallel 2 \
    && cmake --install .

# Verify FastCGI support
RUN /usr/local/bin/mapserv -v | grep -q "SUPPORTS=FASTCGI"

# ============================================================
# Stage 2: Minimal Nginx + MapServer
# ============================================================
FROM nginx:stable-trixie

ENV DEBIAN_FRONTEND=noninteractive

# Runtime dependencies only
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    spawn-fcgi \
    tini \
    libfcgi0ldbl \
    libgdal36 \
    libproj25 \
    proj-data \
    gdal-data \
    libgeos-c1t64 \
    libxml2 \
    libcurl4t64 \
    libpq5 \
    libpng16-16t64 \
    libjpeg62-turbo \
    libtiff6 \
    libfreetype6 \
    libcairo2 \
    libfribidi0 \
    libharfbuzz0b \
    libgif7 \
    libpcre2-posix3 \
    libsqlite3-0 \
    zlib1g \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled MapServer
COPY --from=builder /usr/local/ /usr/local/
COPY --from=builder \
    /build/mapserver/share/ogcapi/templates/html-index-bootstrap/ \
    /usr/local/share/mapserver/ogcapi/templates/html-index-bootstrap/
COPY --from=builder \
    /build/mapserver/share/ogcapi/templates/html-bootstrap/ \
    /usr/local/share/mapserver/ogcapi/templates/html-bootstrap/


RUN ldconfig \
    && ldd /usr/local/bin/mapserv \
    && ! ldd /usr/local/bin/mapserv | grep -q "not found"

RUN mkdir -p /maps \
    && chown nginx:nginx /maps

COPY maps/* /maps/.

# MapServer environment
ENV PROJ_DATA=/usr/share/proj

# ============================================================
# Nginx configuration
# ============================================================
RUN rm -f /etc/nginx/conf.d/default.conf

RUN <<'EOF'
cat > /etc/nginx/conf.d/mapserver.conf <<'NGINX'
server {
    listen 80;
    server_name _;

    location = /health {
        access_log off;
        default_type text/plain;
        return 200 "OK\n";
    }

    location / {
        include fastcgi_params;

        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME /usr/local/bin/mapserv;
        fastcgi_param SCRIPT_NAME "";
        fastcgi_param PATH_INFO $uri;

        fastcgi_connect_timeout 30s;
        fastcgi_send_timeout 120s;
        fastcgi_read_timeout 120s;

        fastcgi_buffering off;
    }
}
NGINX
EOF


RUN <<'EOF'
cat > /maps/mapserver.conf <<'MAPCONF'
CONFIG
  ENV
    MS_MAP_NO_PATH "1"
    MS_ONLINERESOURCE "http://localhost:8080/"
    OGCAPI_HTML_TEMPLATE_DIRECTORY "/usr/local/share/mapserver/ogcapi/templates/html-bootstrap/"
    MS_INDEX_TEMPLATE_DIRECTORY "/usr/local/share/mapserver/ogcapi/templates/html-index-bootstrap/"
  END

  MAPS
    countries "/maps/countries.map"
  END
END
MAPCONF
EOF

ENV MAPSERVER_CONFIG_FILE=/maps/mapserver.conf

# ============================================================
# FastCGI and Nginx startup
# No external entrypoint script required.
# Tini handles child process reaping.
# ============================================================

EXPOSE 80

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/bin/sh", "-ec", "spawn-fcgi -a 127.0.0.1 -p 9000 -F 2 -u nginx -g nginx -f /usr/local/bin/mapserv; exec nginx -g 'daemon off;'"]
