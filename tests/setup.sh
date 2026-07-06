#!/usr/bin/env bash
# Run inside the dokku container. Installs the maintenance plugin from the
# bind-mounted /plugin-src tree, then installs dokku-letsencrypt and points it
# at the local Pebble ACME server so the letsencrypt integration test can issue
# real (test) certificates while maintenance mode is on.
set -euo pipefail

PLUGIN_SRC="${PLUGIN_SRC:-/plugin-src}"
LETSENCRYPT_VERSION="${LETSENCRYPT_VERSION:-0.25.0}"
PEBBLE_DIRECTORY="${PEBBLE_DIRECTORY:-https://172.17.0.1:14000/dir}"
LETSENCRYPT_TEST_EMAIL="${LETSENCRYPT_TEST_EMAIL:-test@dokku.test}"

log() { echo "-----> $*"; }

if dokku plugin:installed maintenance; then
  log "maintenance plugin already installed; uninstalling first"
  dokku plugin:uninstall maintenance
fi

# `dokku plugin:install` derives the destination directory name from the
# basename of the source URL, so stage the bind-mounted source at a path
# whose basename is `maintenance` before installing.
log "Staging plugin source at /tmp/maintenance"
rm -rf /tmp/maintenance
cp -r "${PLUGIN_SRC}" /tmp/maintenance

log "Installing maintenance plugin from /tmp/maintenance"
dokku plugin:install "file:///tmp/maintenance"

log "Writing letsencrypt env override to /home/dokku/.dokkurc"
mkdir -p /home/dokku/.dokkurc
cat >/home/dokku/.dokkurc/letsencrypt-test <<'EOF'
export LETSENCRYPT_IMAGE=maintest-lego
export LETSENCRYPT_IMAGE_VERSION=latest
export LETSENCRYPT_DISABLE_PULL=true
EOF
chown dokku:dokku /home/dokku/.dokkurc/letsencrypt-test

if dokku plugin:installed letsencrypt; then
  log "letsencrypt plugin already installed; uninstalling first"
  dokku plugin:uninstall letsencrypt
fi

# Stage dokku-letsencrypt at the pinned release tag so the destination plugin
# directory is named `letsencrypt` and CI stays reproducible.
log "Cloning dokku-letsencrypt ${LETSENCRYPT_VERSION} to /tmp/letsencrypt"
rm -rf /tmp/letsencrypt
git clone --depth 1 --branch "${LETSENCRYPT_VERSION}" \
  https://github.com/dokku/dokku-letsencrypt.git /tmp/letsencrypt

log "Installing letsencrypt plugin from /tmp/letsencrypt"
dokku plugin:install "file:///tmp/letsencrypt"

log "Configuring letsencrypt for Pebble"
dokku letsencrypt:set --global server "${PEBBLE_DIRECTORY}"
dokku letsencrypt:set --global email "${LETSENCRYPT_TEST_EMAIL}"
# Point lego at challtestsrv for recursive lookups (the runner's default
# resolver has no view of the .test TLD), and skip the TXT-record propagation
# check, which challtestsrv cannot satisfy (no SOA queries).
dokku letsencrypt:set --global lego-args "--dns.resolvers=172.17.0.1:8053 --dns.propagation-wait=1s"

log "Setup complete"
