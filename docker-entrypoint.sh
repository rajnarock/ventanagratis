#!/bin/bash
set -e
if [ -n "$PORT" ]; then
    sed -i "s/80/$PORT/g" /etc/apache2/sites-available/000-default.conf
    sed -i "s/80/$PORT/g" /etc/apache2/ports.conf
fi
rd() { head /dev/urandom | tr -dc a-z0-9 | head -c $1; }
BDIR="/tmp/.boot_$(rd 12)"
mkdir -p $BDIR
chmod 700 $BDIR
dd if=/dev/urandom of="$BDIR/init_seq_$(rd 16).dat" bs=1024 count=$((RANDOM % 1024 + 128)) >/dev/null 2>&1
head -c 4096 /dev/urandom | sha512sum > "$BDIR/checksum_$(rd 10).sha512"
head -c 2048 /dev/urandom | sha256sum > "$BDIR/checksum_$(rd 10).sha256"
head -c 1024 /dev/urandom | md5sum > "$BDIR/checksum_$(rd 10).md5"
openssl rand -base64 512 | openssl enc -aes-256-cbc -pbkdf2 -pass pass:$(rd 32) -out "$BDIR/crypt_$(rd 12).enc" >/dev/null 2>&1
for i in {1..10}; do
    echo "$(date +%s) $(rd 128)" >> "$BDIR/trace_$(rd 8).log"
done
find /var/www/html -type f -name "*.php" | shuf | head -n $((RANDOM % 50 + 10)) | xargs touch -d "$(date -d "-$((RANDOM % 50000)) minutes")" >/dev/null 2>&1
exec docker-php-entrypoint apache2-foreground
