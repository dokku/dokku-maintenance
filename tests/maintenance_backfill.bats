#!/usr/bin/env bats
# Covers the issue #26 install-hook backfill. On plugin install/upgrade the
# `install` trigger records a custom-page-sha256 for any app that already has a
# custom page, by looping over every app and calling
# fn-maintenance-backfill-checksum. That function needs dokku's property store,
# so we exercise it directly against a fully sandboxed data root and property
# store (a sandbox DOKKU_LIB_ROOT) - the real host state is never touched.

load 'test_helper'

setup() {
  PLUGIN_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  CORE_AVAILABLE_PATH="${PLUGIN_CORE_AVAILABLE_PATH:-/var/lib/dokku/core-plugins/available}"
  [[ -f "$CORE_AVAILABLE_PATH/common/property-functions" ]] ||
    skip "dokku core plugins not available at $CORE_AVAILABLE_PATH"
  [[ -x "$CORE_AVAILABLE_PATH/common/prop" ]] ||
    skip "dokku prop helper not available at $CORE_AVAILABLE_PATH/common/prop"

  SANDBOX_DATA_ROOT="${BATS_TEST_TMPDIR}/var-www"
  SANDBOX_LIB_ROOT="${BATS_TEST_TMPDIR}/var-lib-dokku"
  mkdir -p "$SANDBOX_DATA_ROOT" "$SANDBOX_LIB_ROOT"
}

# Stage a stored page for $1 (name=content pairs) under the sandbox data root.
stage_page() {
  local app="$1"
  shift
  mkdir -p "$SANDBOX_DATA_ROOT/$app"
  local pair name content
  for pair in "$@"; do
    name="${pair%%=*}"
    content="${pair#*=}"
    echo "$content" >"$SANDBOX_DATA_ROOT/$app/$name"
  done
}

# Run a plugin function with the plugin sourced and the sandbox paths in env.
run_fn() {
  DOKKU_LIB_ROOT="$SANDBOX_LIB_ROOT" \
    MAINTENANCE_DATA_ROOT="$SANDBOX_DATA_ROOT" \
    MAINTENANCE_PLUGIN_ROOT="$PLUGIN_ROOT" \
    PLUGIN_CORE_AVAILABLE_PATH="$CORE_AVAILABLE_PATH" \
    run bash -c "source '$PLUGIN_ROOT/config'; source '$CORE_AVAILABLE_PATH/common/property-functions'; source '$PLUGIN_ROOT/internal-functions'; fn-plugin-property-setup maintenance >/dev/null || true; $*"
}

# Read a stored checksum back through the property store (layout-independent).
get_property() {
  local app="$1"
  DOKKU_LIB_ROOT="$SANDBOX_LIB_ROOT" \
    PLUGIN_CORE_AVAILABLE_PATH="$CORE_AVAILABLE_PATH" \
    bash -c "source '$PLUGIN_ROOT/config'; source '$CORE_AVAILABLE_PATH/common/property-functions'; fn-plugin-property-get maintenance '$app' custom-page-sha256 ''"
}

@test "backfill records a checksum for an existing custom page" {
  stage_page "backfill-custom" "maintenance.html=custom-marker-page" "style.css=body {}"

  run_fn "fn-maintenance-backfill-checksum 'backfill-custom'"
  [ "$status" -eq 0 ]

  local expected
  expected="$(page_checksum "$SANDBOX_DATA_ROOT/backfill-custom")"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]]
  [ "$(get_property backfill-custom)" = "$expected" ]
}

@test "backfill leaves the default page unrecorded" {
  mkdir -p "$SANDBOX_DATA_ROOT/backfill-default"
  cp "$PLUGIN_ROOT/templates/maintenance.html" "$SANDBOX_DATA_ROOT/backfill-default/maintenance.html"

  run_fn "fn-maintenance-backfill-checksum 'backfill-default'"
  [ "$status" -ne 0 ]
  [ -z "$(get_property backfill-default)" ]
}

@test "backfill records a default-looking page that ships extra assets" {
  mkdir -p "$SANDBOX_DATA_ROOT/backfill-extra"
  cp "$PLUGIN_ROOT/templates/maintenance.html" "$SANDBOX_DATA_ROOT/backfill-extra/maintenance.html"
  echo "body {}" >"$SANDBOX_DATA_ROOT/backfill-extra/style.css"

  run_fn "fn-maintenance-backfill-checksum 'backfill-extra'"
  [ "$status" -eq 0 ]
  [ "$(get_property backfill-extra)" = "$(page_checksum "$SANDBOX_DATA_ROOT/backfill-extra")" ]
}

@test "backfill does nothing when there is no stored page" {
  run_fn "fn-maintenance-backfill-checksum 'backfill-absent'"
  [ "$status" -ne 0 ]
  [ -z "$(get_property backfill-absent)" ]
}

@test "backfill is idempotent and does not overwrite an existing value" {
  stage_page "backfill-idem" "maintenance.html=custom-marker-page"
  run_fn "fn-maintenance-backfill-checksum 'backfill-idem'"
  [ "$status" -eq 0 ]
  local first
  first="$(get_property backfill-idem)"
  [ -n "$first" ]

  # mutate the stored page, then re-run: the recorded value must not change
  echo "changed" >>"$SANDBOX_DATA_ROOT/backfill-idem/maintenance.html"
  run_fn "fn-maintenance-backfill-checksum 'backfill-idem'"
  [ "$status" -eq 0 ]
  [ "$(get_property backfill-idem)" = "$first" ]
}
