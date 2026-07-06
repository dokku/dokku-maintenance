#!/usr/bin/env bash
# Helpers for the dokku-maintenance bats suite. Sourced by every *.bats file.

# `SUDO` is empty in compose mode (bats already runs as root in the dokku
# container) and `sudo` in native mode (where the runner user can't read
# files under /home/dokku/<app>/ without elevation).
SUDO="${SUDO:-}"

new_app_name() {
  echo "maintest-${BATS_TEST_NUMBER:-0}-$(date +%s)-${RANDOM}"
}

create_app() {
  local app="$1"
  dokku apps:create "$app"
}

cleanup_app() {
  local app="$1"
  if dokku apps:exists "$app" >/dev/null 2>&1; then
    dokku --force apps:destroy "$app" >/dev/null 2>&1 || true
  fi
}

maintenance_conf_path() {
  local app="$1"
  echo "/home/dokku/${app}/nginx.conf.d/maintenance.conf"
}

maintenance_page_path() {
  local app="$1"
  echo "/home/dokku/${app}/maintenance/maintenance.html"
}

# Builds a tarball at $1 containing the remaining arguments, given as
# name=content pairs. Files are staged in a scratch dir under
# $BATS_TEST_TMPDIR so bats cleans them up.
make_tarball() {
  local tarball="$1"
  shift
  local stage="${BATS_TEST_TMPDIR}/tarball-stage-${RANDOM}"
  mkdir -p "$stage"
  local pair name content
  for pair in "$@"; do
    name="${pair%%=*}"
    content="${pair#*=}"
    echo "$content" >"${stage}/${name}"
  done
  tar -cf "$tarball" -C "$stage" .
}
