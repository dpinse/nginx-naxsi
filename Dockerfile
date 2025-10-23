# syntax=docker/dockerfile:1.7

########################
#  Builder (compile)   #
########################
FROM alpine:3.20 AS build

ARG NGINX_VERSION=1.29.2
ARG NAXSI_VERSION=1.7

# Build deps
RUN apk add --no-cache \
    build-base curl git pkgconf \
    pcre2-dev zlib-dev openssl-dev linux-headers perl-dev

WORKDIR /tmp

# Fetch Nginx source
RUN curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -o nginx.tar.gz \
 && tar xzf nginx.tar.gz

# Fetch NAXSI (with libinjection submodule)
RUN git clone --depth 1 --branch "${NAXSI_VERSION}" --recurse-submodules \
      https://github.com/wargio/naxsi.git "/tmp/naxsi-${NAXSI_VERSION}"

WORKDIR "/tmp/nginx-${NGINX_VERSION}"

# Build nginx and the naxsi module (dynamic)
# - --with-compat lets the module load across compatible Nginx builds
RUN ./configure \
      --prefix=/etc/nginx \
      --sbin-path=/usr/sbin/nginx \
      --conf-path=/etc/nginx/nginx.conf \
      --error-log-path=/var/log/nginx/error.log \
      --http-log-path=/var/log/nginx/access.log \
      --pid-path=/var/run/nginx.pid \
      --lock-path=/var/run/nginx.lock \
      --with-http_ssl_module \
      --with-threads \
      --with-file-aio \
      --with-pcre-jit \
      --with-compat \
      --add-dynamic-module="/tmp/naxsi-${NAXSI_VERSION}/naxsi_src" \
  && make -j"$(nproc)" modules \
  && make -j"$(nproc)" \
  && make install

# Stash the built dynamic module where we can copy it later
RUN mkdir -p /out/modules \
 && cp -v objs/ngx_http_naxsi_module.so /out/modules/

########################
#    Runtime (slim)    #
########################
FROM alpine:3.20

# Minimal runtime deps
RUN addgroup -S nginx && adduser -S -G nginx nginx \
 && apk add --no-cache pcre2 zlib openssl ca-certificates \
 && mkdir -p /var/log/nginx /var/cache/nginx /etc/nginx/modules \
 && chown -R nginx:nginx /var/log/nginx /var/cache/nginx

# Bring in nginx and default tree (no custom config/rules baked in)
COPY --from=build /usr/sbin/nginx /usr/sbin/nginx
COPY --from=build /etc/nginx /etc/nginx
# Bring in the NAXSI dynamic module
COPY --from=build /out/modules/ngx_http_naxsi_module.so /etc/nginx/modules/ngx_http_naxsi_module.so

# OCI labels
ARG NGINX_VERSION
ARG NAXSI_VERSION
LABEL org.opencontainers.image.title="nginx + naxsi (dynamic module)" \
      org.opencontainers.image.description="Nginx ${NGINX_VERSION} with NAXSI ${NAXSI_VERSION} as a dynamic module. Config and rules are mounted at runtime." \
      org.opencontainers.image.version="${NGINX_VERSION}" \
      org.opencontainers.image.licenses="MIT"

EXPOSE 80 443
STOPSIGNAL SIGQUIT
USER nginx

# No config baked in; your mounted nginx.conf must 'load_module modules/ngx_http_naxsi_module.so;'
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
