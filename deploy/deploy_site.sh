#!/usr/bin/env bash
# Publishes the website (from GitHub main) to https://eazy2buychina.com on EC2.
set -euo pipefail
ssh -o ConnectTimeout=20 -i "C:\Users\hp\UNILODGE\fadex.pem" ubuntu@13.48.31.7 'set -e
  cd ~/m2c-app && git pull -q && git log --oneline -1
  sudo rsync -a --delete --exclude ".git" --exclude "backend" --exclude "mobile" --exclude "*.md" --exclude ".gitignore" --exclude "render.yaml" ~/m2c-app/ /var/www/eazy2buy-site/
  sudo chown -R www-data:www-data /var/www/eazy2buy-site
  echo "website published"'
