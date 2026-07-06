#!/usr/bin/env bash
# Run on a Linux host (Ubuntu 24.04). Bootstraps Dokku natively, installs the
# maintenance plugin from the working tree, and installs dokku-letsencrypt
# pointed at the Pebble services that the compose stack started in the
# background.
set -euo pipefail

PLUGIN_SRC="${PLUGIN_SRC:-${GITHUB_WORKSPACE:-$(pwd)}}"
LETSENCRYPT_VERSION="${LETSENCRYPT_VERSION:-0.25.0}"
PEBBLE_DIRECTORY="${PEBBLE_DIRECTORY:-https://172.17.0.1:14000/dir}"
LETSENCRYPT_TEST_EMAIL="${LETSENCRYPT_TEST_EMAIL:-test@dokku.test}"
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

log "Writing letsencrypt env override to /home/dokku/.dokkurc"
sudo mkdir -p /home/dokku/.dokkurc
sudo tee /home/dokku/.dokkurc/letsencrypt-test >/dev/null <<'EOF'
export LETSENCRYPT_IMAGE=maintest-lego
export LETSENCRYPT_IMAGE_VERSION=latest
export LETSENCRYPT_DISABLE_PULL=true
EOF
sudo chown dokku:dokku /home/dokku/.dokkurc/letsencrypt-test

if sudo dokku plugin:installed letsencrypt; then
  log "letsencrypt plugin already installed; uninstalling first"
  sudo dokku plugin:uninstall letsencrypt
fi

log "Cloning dokku-letsencrypt ${LETSENCRYPT_VERSION} to /tmp/letsencrypt"
sudo rm -rf /tmp/letsencrypt
sudo git clone --depth 1 --branch "${LETSENCRYPT_VERSION}" \
  https://github.com/dokku/dokku-letsencrypt.git /tmp/letsencrypt

log "Installing letsencrypt plugin from /tmp/letsencrypt"
sudo dokku plugin:install "file:///tmp/letsencrypt"

log "Configuring letsencrypt for Pebble"
sudo dokku letsencrypt:set --global server "${PEBBLE_DIRECTORY}"
sudo dokku letsencrypt:set --global email "${LETSENCRYPT_TEST_EMAIL}"
# Point lego at challtestsrv for recursive lookups (the runner's default
# resolver has no view of the .test TLD), and skip the TXT-record propagation
# check, which challtestsrv cannot satisfy (no SOA queries).
sudo dokku letsencrypt:set --global lego-args "--dns.resolvers=172.17.0.1:8053 --dns.propagation-wait=1s"

log "Setup complete"
