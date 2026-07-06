#!/usr/bin/env bats
# Proves issue #10 is fixed: the maintenance nginx include no longer swallows
# the ACME HTTP-01 challenge, so dokku-letsencrypt can issue and renew
# certificates while maintenance mode is on. Runs against a local Pebble ACME
# server; skips when that stack (or the letsencrypt plugin) is unavailable.

load 'test_helper'

setup() {
  ensure_letsencrypt_stack
  APP="$(new_app_name)"
  DOMAIN="${APP}.${TEST_DOMAIN_BASE}"
  create_app "$APP"
  set_domain "$APP" "$DOMAIN"
  register_a_record "$DOMAIN"
}

teardown() {
  clear_a_record "$DOMAIN"
  cleanup_app "$APP"
}

@test "letsencrypt:enable issues a cert while maintenance mode is on" {
  dokku maintenance:enable "$APP"

  run dokku letsencrypt:enable "$APP"
  [ "$status" -eq 0 ]

  assert_cert_exists "$APP"
  assert_cert_issued_by_pebble "$APP"
  assert_cert_san_contains "$APP" "$DOMAIN"

  # maintenance mode is still active after issuance
  run dokku maintenance:report "$APP" --maintenance-enabled
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "letsencrypt:enable renews a cert while maintenance mode is on" {
  # Pebble issues 24h certs; shrink the grace period so --force is a real renew.
  dokku letsencrypt:set "$APP" graceperiod 60
  dokku letsencrypt:enable "$APP"

  dokku maintenance:enable "$APP"

  run dokku letsencrypt:enable "$APP" --force
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "Certificate retrieved successfully"

  assert_cert_exists "$APP"
  assert_cert_issued_by_pebble "$APP"
}
