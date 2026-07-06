#!/usr/bin/env bash
# Helpers for the dokku-maintenance bats suite. Sourced by every *.bats file.

# `SUDO` is empty in compose mode (bats already runs as root in the dokku
# container) and `sudo` in native mode (where the runner user can't read
# files under /home/dokku/<app>/ without elevation).
SUDO="${SUDO:-}"

# Reach the Pebble supporting services via 172.17.0.1 (the docker bridge
# gateway, which is a real interface on the host as well). Only the
# letsencrypt integration test uses these.
CHALLTESTSRV_URL="${CHALLTESTSRV_URL:-http://172.17.0.1:8055}"
TEST_DOMAIN_BASE="${TEST_DOMAIN_BASE:-dokku.test}"
DEFAULT_A_TARGET="${DEFAULT_A_TARGET:-172.17.0.1}"

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

# --- letsencrypt integration helpers ---------------------------------------
# Used only by maintenance_letsencrypt.bats. Ported from dokku-letsencrypt's
# test suite so the maintenance fix can be proven against a real Pebble ACME
# server while maintenance mode is on.

# Skip the calling test unless the full Pebble stack and the letsencrypt plugin
# are available (e.g. outside the Linux CI stack).
ensure_letsencrypt_stack() {
  command -v curl >/dev/null 2>&1 || skip "curl is required for the letsencrypt integration test"
  # `plugin:installed` is a root-only command, so query it through $SUDO (empty
  # in compose mode where bats already runs as root, `sudo` in native mode).
  $SUDO dokku plugin:installed letsencrypt >/dev/null 2>&1 || skip "letsencrypt plugin is not installed"
  curl -s -o /dev/null --max-time 5 "${CHALLTESTSRV_URL}/" ||
    skip "pebble-challtestsrv is not reachable at ${CHALLTESTSRV_URL}"
}

set_domain() {
  local app="$1" domain="$2"
  dokku domains:set "$app" "$domain"
}

add_domain() {
  local app="$1" domain="$2"
  dokku domains:add "$app" "$domain"
}

register_a_record() {
  local host="$1" target="${2:-$DEFAULT_A_TARGET}"
  case "$host" in
    *.) ;;
    *) host="${host}." ;;
  esac
  curl -sf -X POST -H 'Content-Type: application/json' \
    -d "{\"host\":\"${host}\",\"addresses\":[\"${target}\"]}" \
    "${CHALLTESTSRV_URL}/add-a" >/dev/null
}

clear_a_record() {
  local host="$1"
  case "$host" in
    *.) ;;
    *) host="${host}." ;;
  esac
  curl -sf -X POST -H 'Content-Type: application/json' \
    -d "{\"host\":\"${host}\"}" \
    "${CHALLTESTSRV_URL}/clear-a" >/dev/null || true
}

cert_path_for() {
  local app="$1"
  echo "/home/dokku/${app}/tls/server.letsencrypt.crt"
}

cert_issuer() {
  $SUDO openssl x509 -in "$1" -noout -issuer
}

cert_san() {
  $SUDO openssl x509 -in "$1" -noout -text | awk '/X509v3 Subject Alternative Name/{getline; print}'
}

assert_cert_exists() {
  local app="$1"
  local crt
  crt="$(cert_path_for "$app")"
  $SUDO test -f "$crt" || {
    echo "expected cert at $crt" >&2
    return 1
  }
}

assert_cert_issued_by_pebble() {
  local app="$1"
  local crt
  crt="$(cert_path_for "$app")"
  cert_issuer "$crt" | grep -qi pebble || {
    echo "expected Pebble issuer; got: $(cert_issuer "$crt")" >&2
    return 1
  }
}

assert_cert_san_contains() {
  local app="$1" needle="$2"
  local crt
  crt="$(cert_path_for "$app")"
  cert_san "$crt" | grep -qF "$needle" || {
    echo "expected SAN to contain '$needle'; got: $(cert_san "$crt")" >&2
    return 1
  }
}
