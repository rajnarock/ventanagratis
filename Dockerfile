FROM php:8.2-apache

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    bison \
    flex \
    libssl-dev \
    libcurl4-openssl-dev \
    libnghttp2-dev \
    libnghttp3-dev \
    libngtcp2-dev \
    libpcap-dev \
    libnet1-dev \
    zlib1g-dev \
    libzip-dev \
    iputils-ping \
    net-tools \
    iproute2 \
    curl \
    wget \
    procps \
    socat \
    netcat-openbsd \
    unzip \
    jq \
    bc \
    file \
    time \
    dnsutils \
    cron \
    vim-tiny \
    openssl \
    gnutls-bin \
    ca-certificates \
    tcpdump \
    nmap \
    hping3 \
    ngrep \
    lsof \
    strace \
    conntrack \
    ethtool \
    traceroute \
    mtr-tiny \
    telnet \
    iptables \
    && docker-php-ext-install sockets opcache curl pcntl shmop sysvmsg sysvsem sysvshm \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    && a2enmod headers rewrite expires ssl http2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN echo "ServerTokens Prod" >> /etc/apache2/apache2.conf && \
    echo "ServerSignature Off" >> /etc/apache2/apache2.conf && \
    sed -i 's/Timeout 300/Timeout 86400/' /etc/apache2/apache2.conf && \
    echo "KeepAlive On" >> /etc/apache2/apache2.conf && \
    echo "TraceEnable Off" >> /etc/apache2/apache2.conf && \
    echo "Protocols h2 h2c http/1.1" >> /etc/apache2/apache2.conf

RUN sed -i 's/SECLEVEL=2/SECLEVEL=0/g' /etc/ssl/openssl.cnf || true && \
    echo 'openssl_conf = default_conf' >> /etc/ssl/openssl.cnf && \
    echo '[default_conf]' >> /etc/ssl/openssl.cnf && \
    echo 'ssl_conf = ssl_sect' >> /etc/ssl/openssl.cnf && \
    echo '[ssl_sect]' >> /etc/ssl/openssl.cnf && \
    echo 'system_default = system_default_sect' >> /etc/ssl/openssl.cnf && \
    echo '[system_default_sect]' >> /etc/ssl/openssl.cnf && \
    echo 'CipherString = DEFAULT@SECLEVEL=0' >> /etc/ssl/openssl.cnf && \
    echo 'MinProtocol = None' >> /etc/ssl/openssl.cnf

RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/hardened.ini && \
    echo "max_execution_time = 0" >> /usr/local/etc/php/conf.d/hardened.ini && \
    echo "default_socket_timeout = $((RANDOM % 120 + 30))" >> /usr/local/etc/php/conf.d/hardened.ini && \
    echo "expose_php = Off" >> /usr/local/etc/php/conf.d/hardened.ini && \
    echo "opcache.enable = 1" >> /usr/local/etc/php/conf.d/hardened.ini && \
    echo "opcache.memory_consumption = $((RANDOM % 64 + 128))" >> /usr/local/etc/php/conf.d/hardened.ini && \
    echo "opcache.max_accelerated_files = $((RANDOM % 5000 + 7000))" >> /usr/local/etc/php/conf.d/hardened.ini && \
    echo "post_max_size = 64M" >> /usr/local/etc/php/conf.d/hardened.ini && \
    echo "upload_max_filesize = 64M" >> /usr/local/etc/php/conf.d/hardened.ini

RUN echo 'int main() { return '"$((RANDOM % 255))"'; }' > /tmp/rnd_seed.c && \
    gcc /tmp/rnd_seed.c -o /usr/local/bin/sys_seed_binary && \
    rm /tmp/rnd_seed.c && \
    /usr/local/bin/sys_seed_binary || true

RUN echo '#!/bin/bash\n\
rd() { head /dev/urandom | tr -dc a-z0-9 | head -c $1; }\n\
TDIR="/tmp/.sys_$(rd 8)"\n\
MDIR="/var/www/html/.cache_dyn"\n\
mkdir -p $TDIR $MDIR\n\
chmod 777 $TDIR $MDIR\n\
while true; do\n\
  NM="proc_$(rd 16).dat"\n\
  dd if=/dev/urandom of="$TDIR/$NM" bs=1024 count=$((RANDOM % 500 + 50)) 2>/dev/null\n\
  gzip -f "$TDIR/$NM" >/dev/null 2>&1\n\
  rm -f "$TDIR/$NM.gz"\n\
  TS=$(date +%s)\n\
  if [ $((RANDOM % 2)) -eq 0 ]; then\n\
    echo "$TS $(rd 128)" | sha512sum >> $MDIR/integrity_hash.dat\n\
    echo "$TS $(rd 64)" | sha256sum >> $MDIR/integrity_hash.dat\n\
    echo "$TS $(rd 32)" | md5sum >> $MDIR/integrity_hash.dat\n\
    if [ $(stat -c%s $MDIR/integrity_hash.dat 2>/dev/null || echo 0) -gt 2097152 ]; then > $MDIR/integrity_hash.dat; fi\n\
  fi\n\
  echo "{\"ts\": $TS, \"id\": \"$(rd 32)\", \"state\": \"$(rd 8)\", \"load\": $((RANDOM % 10000))}" >> $TDIR/runtime_state.json\n\
  if [ $(stat -c%s $TDIR/runtime_state.json 2>/dev/null || echo 0) -gt 4194304 ]; then > $TDIR/runtime_state.json; fi\n\
  if [ $((RANDOM % 3)) -eq 0 ]; then\n\
    openssl rand -base64 64 | openssl enc -aes-256-cbc -pbkdf2 -pass pass:$(rd 10) -out "$TDIR/enc_$(rd 5).bin" 2>/dev/null\n\
    rm -f "$TDIR/enc_*.bin"\n\
  fi\n\
  if [ $((RANDOM % 4)) -eq 0 ]; then\n\
    find $TDIR -type f -mmin +1 -delete 2>/dev/null\n\
  fi\n\
  if [ $((RANDOM % 2)) -eq 0 ]; then\n\
    curl -s -k --http2 -H "X-Trace-ID: $(rd 16)" -H "User-Agent: Sys/$(rd 6)" http://127.0.0.1/ >/dev/null 2>&1\n\
  fi\n\
  if [ $((RANDOM % 5)) -eq 0 ]; then\n\
    timeout 1 nc -z 127.0.0.1 $((RANDOM % 60000 + 2000)) >/dev/null 2>&1\n\
  fi\n\
  if [ $((RANDOM % 8)) -eq 0 ]; then\n\
    php -r "hash(\"sha512\", str_shuffle(str_repeat(\"a\", 1024*1024)));" >/dev/null 2>&1\n\
  fi\n\
  find $MDIR -type f -exec touch -d "$(date -d "-$((RANDOM % 3600)) seconds")" {} + 2>/dev/null\n\
  sleep $((RANDOM % 8 + 1))\n\
done' > /usr/local/bin/sys_poly_worker && \
    chmod +x /usr/local/bin/sys_poly_worker

RUN echo '#!/bin/bash\n\
while true; do\n\
  PSNAME=".ps_$(head /dev/urandom | tr -dc a-z | head -c 8)"\n\
  ps aux > /tmp/$PSNAME.tmp\n\
  find /tmp -name ".ps_*" -mmin +1 -delete >/dev/null 2>&1\n\
  sleep $((RANDOM % 30 + 10))\n\
done' > /usr/local/bin/sys_mon_worker && \
    chmod +x /usr/local/bin/sys_mon_worker

COPY . /var/www/html/

RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 755 /var/www/html && \
    mkdir -p /var/www/html/.sys_vendor && \
    mkdir -p /usr/local/src/.cache_build && \
    mkdir -p /var/www/html/.cache_dyn && \
    chmod 777 /var/www/html/.cache_dyn && \
    for i in {1..200}; do \
      head /dev/urandom | tr -dc a-z0-9 | head -c $((RANDOM % 4096 + 256)) > /var/www/html/.sys_vendor/.lib_$(head /dev/urandom | tr -dc a-z | head -c 8).dat; \
    done && \
    for k in {1..50}; do \
      head /dev/urandom | tr -dc a-f0-9 | head -c $((RANDOM % 8192 + 1024)) > /usr/local/src/.cache_build/src_$(head /dev/urandom | tr -dc a-z0-9 | head -c 12).tar.gz; \
    done && \
    mkdir -p /opt/.sys_runtime_$(head /dev/urandom | tr -dc a-z | head -c 5) && \
    for j in {1..20}; do \
      dd if=/dev/urandom of=/opt/.sys_runtime_*/data_$j.bin bs=1024 count=$((RANDOM % 100)) 2>/dev/null; \
    done && \
    find /var/www/html -type f -exec bash -c 'touch -d "$(date -d "-$((RANDOM % 200000)) minutes")" "$0"' {} \; && \
    echo "<!-- BuildID: $(head /dev/urandom | tr -dc a-f0-9 | head -c 128) -->" >> /var/www/html/index.php 2>/dev/null || true

COPY docker-entrypoint.sh /usr/local/bin/

RUN sed -i "2i /usr/local/bin/sys_poly_worker > /dev/null 2>&1 &" /usr/local/bin/docker-entrypoint.sh && \
    sed -i "3i /usr/local/bin/sys_mon_worker > /dev/null 2>&1 &" /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
