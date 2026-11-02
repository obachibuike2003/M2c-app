#!/usr/bin/env bash
# Builds the Eazy2buy Flutter app for the web and publishes it to https://app.eazy2buychina.com
# (also served at app.13-48-31-7.sslip.io). Needs the EC2 key at the path below.
set -euo pipefail
APP="/c/Users/hp/muller app"
KEY="C:\\Users\\hp\\UNILODGE\\fadex.pem"
cd "$APP/mobile"
powershell -NoProfile -Command "flutter build web --release --dart-define=SITE_BASE= --dart-define=BUILD=$(date +%d%b-%H%M) --no-web-resources-cdn --no-wasm-dry-run -o build\\web_live" | tail -1
cp -r "$APP/assets/products" build/web_live/assets/
cp -r "$APP/assets/banners" build/web_live/assets/
tar -czf build/web_live.tgz -C build/web_live .
scp -q -o ConnectTimeout=20 -i "$KEY" build/web_live.tgz ubuntu@13.48.31.7:/tmp/m2c-app-web.tgz
ssh -o ConnectTimeout=20 -i "$KEY" ubuntu@13.48.31.7 'set -e
  sudo rm -rf /var/www/m2c-app-web.new && sudo mkdir -p /var/www/m2c-app-web.new
  sudo tar -xzf /tmp/m2c-app-web.tgz -C /var/www/m2c-app-web.new && rm /tmp/m2c-app-web.tgz
  sudo chown -R www-data:www-data /var/www/m2c-app-web.new
  # Swap in one step, so nobody loads a half-copied app.
  sudo rm -rf /var/www/m2c-app-web.old && sudo mv /var/www/m2c-app-web /var/www/m2c-app-web.old
  sudo mv /var/www/m2c-app-web.new /var/www/m2c-app-web && sudo rm -rf /var/www/m2c-app-web.old
  echo published'
curl -s -o /dev/null -w "https://app.13-48-31-7.sslip.io -> %{http_code}\n" https://app.13-48-31-7.sslip.io/
