#!/bin/bash
set -e

# Si la variable de entorno PORT está definida (común en Cloud Run, Heroku, etc.)
if [ -n "$PORT" ]; then
    echo "Configurando Apache para escuchar en el puerto $PORT..."
    sed -i "s/80/$PORT/g" /etc/apache2/sites-available/000-default.conf
    sed -i "s/80/$PORT/g" /etc/apache2/ports.conf
fi

# Ejecutar el comando original de la imagen (apache en foreground)
exec docker-php-entrypoint apache2-foreground