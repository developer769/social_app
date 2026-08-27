#!/usr/bin/env bash
# Brings Prachar up on a fresh Ubuntu host. Run as root.
#
#   scp -r . root@HOST:/opt/prachar && ssh root@HOST 'bash /opt/prachar/deploy/install.sh'
#
# Idempotent: safe to run again after a change.
set -euo pipefail

APP_DIR="/opt/prachar"
DOMAIN="${APP_HOST:-prachar.dcrayons.app}"

echo "==> Docker"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

echo "==> nginx and certbot"
apt-get update -qq
apt-get install -y -qq nginx certbot python3-certbot-nginx >/dev/null

echo "==> checking secrets"
if [ ! -f "$APP_DIR/.env.production" ]; then
  echo "MISSING $APP_DIR/.env.production -- copy .env.production.example and fill it in." >&2
  exit 1
fi

echo "==> building and starting the stack"
cd "$APP_DIR"
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build

echo "==> waiting for the app"
for i in $(seq 1 40); do
  if curl -fsS -o /dev/null http://127.0.0.1:3000/up; then echo "    up"; break; fi
  sleep 3
done

echo "==> database"
docker compose -f docker-compose.prod.yml --env-file .env.production run --rm web bin/rails db:prepare

echo "==> nginx"
sed "s/APP_HOST_PLACEHOLDER/$DOMAIN/g" deploy/nginx.conf > /etc/nginx/sites-available/prachar
ln -sf /etc/nginx/sites-available/prachar /etc/nginx/sites-enabled/prachar
rm -f /etc/nginx/sites-enabled/default
mkdir -p /var/www/certbot

# The TLS block references a certificate that does not exist yet, so serve
# plain http first, get the certificate, then enable the full config.
if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  echo "==> certificate for $DOMAIN"
  printf 'server {\n listen 80;\n server_name %s;\n location /.well-known/acme-challenge/ { root /var/www/certbot; }\n location / { proxy_pass http://127.0.0.1:3000; proxy_set_header Host $host; }\n}\n' "$DOMAIN" \
    > /etc/nginx/sites-available/prachar
  nginx -t && systemctl reload nginx
  certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN" --agree-tos --register-unsafely-without-email --non-interactive
  sed "s/APP_HOST_PLACEHOLDER/$DOMAIN/g" deploy/nginx.conf > /etc/nginx/sites-available/prachar
fi

nginx -t && systemctl reload nginx

echo
echo "Done. https://$DOMAIN"
echo "Renewal is handled by certbot's timer; check with: systemctl list-timers | grep certbot"
