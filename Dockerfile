FROM php:8.2-apache

ARG BUILD_EPOCH=0
ARG BUILD_NONCE=init

LABEL maintainer="Ghost" \
      org.opencontainers.image.created="${BUILD_EPOCH}" \
      org.opencontainers.image.revision="${BUILD_NONCE}" \
      org.opencontainers.image.id="${BUILD_NONCE}-${BUILD_EPOCH}" \
      local.random.seed="${BUILD_NONCE}"

RUN echo "Cache Busting: ${BUILD_EPOCH}-${BUILD_NONCE}" > /dev/null && \
    apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    iputils-ping \
    procps \
    && docker-php-ext-install sockets opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "Installed on ${BUILD_EPOCH}" > /etc/build_timestamp

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    sed -i 's/Timeout 300/Timeout 3600/' /etc/apache2/apache2.conf && \
    echo "CustomLog /dev/null common" > /etc/apache2/conf-available/nolog.conf && \
    a2enconf nolog

RUN { \
        echo 'memory_limit = 512M'; \
        echo 'max_execution_time = 0'; \
        echo 'output_buffering = Off'; \
        echo 'implicit_flush = On'; \
        echo 'zlib.output_compression = Off'; \
        echo "expose_php = Off"; \
    } > /usr/local/etc/php/conf.d/custom_net.ini

RUN echo '#!/bin/bash\n\
while true; do \n\
    RAND_VAL=$(head -n 10 /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)\n\
    echo "$RAND_VAL" > /tmp/dynamic_noise.dat\n\
    touch -d "$(date -R -r /tmp/dynamic_noise.dat)" /tmp/dynamic_noise.dat\n\
    find /tmp -name "sess_*" -mmin +60 -delete > /dev/null 2>&1\n\
    sleep $(( ( RANDOM % 10 )  + 5 ))\n\
done' > /usr/local/bin/polymorph_daemon.sh && \
chmod +x /usr/local/bin/polymorph_daemon.sh

COPY . /var/www/html/
RUN echo "${BUILD_NONCE}" > /var/www/html/nonce.txt && \
    chown -R www-data:www-data /var/www/html && \
    chmod -R 755 /var/www/html

COPY docker-entrypoint.sh /usr/local/bin/
RUN sed -i '2i /usr/local/bin/polymorph_daemon.sh > /dev/null 2>\&1 &' /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
