#!/usr/bin/env bash
# Run inside the dokku container. Installs the plugin from the bind-mounted
# /plugin-src tree.
set -euo pipefail

PLUGIN_SRC="${PLUGIN_SRC:-/plugin-src}"

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

log "Setup complete"
