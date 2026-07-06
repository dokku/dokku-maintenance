#!/usr/bin/env bash
# Run on a Linux host (Ubuntu 24.04). Bootstraps Dokku natively and installs
# the plugin from the working tree.
set -euo pipefail

PLUGIN_SRC="${PLUGIN_SRC:-${GITHUB_WORKSPACE:-$(pwd)}}"
DOKKU_TAG="${DOKKU_TAG:-}"

log() { echo "-----> $*"; }

if ! command -v dokku >/dev/null 2>&1; then
  log "Preparing apt/nginx prerequisites for dokku bootstrap"
  sudo mkdir -p /etc/nginx
  sudo curl -fsSL https://raw.githubusercontent.com/dokku/dokku/master/tests/dhparam.pem -o /etc/nginx/dhparam.pem
  echo "dokku dokku/skip_key_file boolean true" | sudo debconf-set-selections
  echo "dokku dokku/hostname string dokku.test" | sudo debconf-set-selections
  echo "dokku dokku/vhost_enable boolean true" | sudo debconf-set-selections
  echo "dokku dokku/web_config boolean false" | sudo debconf-set-selections

  log "Downloading dokku bootstrap.sh"
  curl -fsSL https://raw.githubusercontent.com/dokku/dokku/master/bootstrap.sh -o /tmp/dokku-bootstrap.sh
  if [ -n "$DOKKU_TAG" ]; then
    log "Running bootstrap.sh with DOKKU_TAG=$DOKKU_TAG"
    sudo DOKKU_TAG="$DOKKU_TAG" bash /tmp/dokku-bootstrap.sh
  else
    log "Running bootstrap.sh (latest)"
    sudo bash /tmp/dokku-bootstrap.sh
  fi
else
  log "dokku already installed; skipping bootstrap"
fi

if sudo dokku plugin:installed maintenance; then
  log "maintenance plugin already installed; uninstalling first"
  sudo dokku plugin:uninstall maintenance
fi

# `dokku plugin:install` derives the destination directory name from the
# basename of the source URL, so stage the plugin source at a path whose
# basename is `maintenance` before installing.
log "Staging plugin source at /tmp/maintenance"
sudo rm -rf /tmp/maintenance
sudo cp -r "${PLUGIN_SRC}" /tmp/maintenance

log "Installing maintenance plugin from /tmp/maintenance"
sudo dokku plugin:install "file:///tmp/maintenance"

log "Setup complete"
