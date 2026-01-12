FROM php:8.2-apache

# Instalación de dependencias del sistema y extensiones PHP
# 'sockets' es crítico para el script
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    iputils-ping \
    && docker-php-ext-install sockets opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configuración Apache
# Ajustamos timeouts y deshabilitamos logs de acceso para no saturar el disco I/O
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    sed -i 's/Timeout 300/Timeout 3600/' /etc/apache2/apache2.conf && \
    echo "CustomLog /dev/null common" > /etc/apache2/conf-available/nolog.conf && \
    a2enconf nolog

# Configuración PHP Personalizada
# output_buffering = Off es vital para ver el progreso en tiempo real
RUN { \
        echo 'memory_limit = 512M'; \
        echo 'max_execution_time = 0'; \
        echo 'output_buffering = Off'; \
        echo 'implicit_flush = On'; \
        echo 'zlib.output_compression = Off'; \
    } > /usr/local/etc/php/conf.d/custom_net.ini

COPY . /var/www/html/
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 755 /var/www/html

# Copiamos el entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]