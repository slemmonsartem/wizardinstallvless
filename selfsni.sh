#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Использование: $0 <domain> <email>"
  exit 1
fi

DOMAIN="$1"
EMAIL="$2"
WEBROOT="/var/www/html/site"
NGINX_AVAILABLE="/etc/nginx/sites-available/sni.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/sni.conf"
LE_PATH="/etc/letsencrypt/live/$DOMAIN"

if [[ $EUID -ne 0 ]]; then
  echo "Запусти от root"
  exit 1
fi

echo "==> Установка nginx и certbot"
apt update
apt install -y nginx certbot python3-certbot-nginx

echo "==> Удаляю default конфиг"
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

echo "==> Создаю папку сайта"
mkdir -p "$WEBROOT"

echo "==> Создаю index.html"
cat > "$WEBROOT/index.html" <<EOF
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
  </head>
  <body>
  </body>
</html>
EOF

echo "==> Временный конфиг nginx"
cat > "$NGINX_AVAILABLE" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        root $WEBROOT;
        index index.html;
    }
}
EOF

ln -sf "$NGINX_AVAILABLE" "$NGINX_ENABLED"

nginx -t
systemctl restart nginx

echo "==> Получаю сертификат"
certbot --nginx \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  -d "$DOMAIN" \
  --redirect

echo "==> Финальный конфиг (Reality)"
cat > "$NGINX_AVAILABLE" <<EOF
server {
    listen 127.0.0.1:8443 ssl http2 proxy_protocol;
    server_name $DOMAIN;

    ssl_certificate $LE_PATH/fullchain.pem;
    ssl_certificate_key $LE_PATH/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';

    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;

    real_ip_header proxy_protocol;
    set_real_ip_from 127.0.0.1;
    set_real_ip_from ::1;

    root $WEBROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

nginx -t
systemctl restart nginx

echo "Готово"
echo "DEST: 127.0.0.1:8443"
echo "SNI: $DOMAIN"
echo "xver: 1"
