#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

UI_PORT=$(shuf -i 10000-65535 -n1)
HTTP_PORT=$(shuf -i 10000-65535 -n1)
MAIL=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
DOMAIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
MAIN_IP=$(hostname --ip-address)
username=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)

sudo apt-get update
sudo apt-get upgrade -y
echo y | sudo apt install ufw

ufw allow ${UI_PORT}/tcp
ufw allow ${HTTP_PORT}/tcp
ufw allow 443/tcp
ufw allow 80/tcp
ufw allow 22/tcp

echo y | ufw enable
ufw status verbose

echo n | bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) v2.4.11
/usr/local/x-ui/x-ui setting -username ${username} -password ${password} -port ${UI_PORT} -webBasePath "/"

wget https://github.com/caddyserver/caddy/releases/download/v2.6.4/caddy_2.6.4_linux_amd64.deb
dpkg -i caddy_2.6.4_linux_amd64.deb



# Caddy config: ONLY this port, ONLY internal TLS, no https_port/http_port hacks
rm -rf /etc/caddy/Caddyfile
cat << EOF | sudo tee /etc/caddy/Caddyfile >/dev/null
{
  auto_https off
  log {
    level ERROR
  }
}

:${HTTPS_PORT} {
  tls internal
  reverse_proxy 127.0.0.1:${UI_PORT}
}
EOF

systemctl restart caddy

echo -e "${green}x-ui ${plain} installation finished, it is running now..."
echo -e "###############################################"
echo -e "username: ${username}${plain}"
echo -e "password: ${password}${plain}"
echo -e "###############################################"
echo -e "The panel is available at: ${HTTP_PORT}${plain}"
echo -e "###############################################"
