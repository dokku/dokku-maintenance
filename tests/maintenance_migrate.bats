#!/usr/bin/env bats
# Covers the issue #19 upgrade migration. On plugin install/upgrade the `install`
# trigger loops over every app and calls fn-maintenance-migrate-app, relocating
# assets out of the legacy /home/dokku/<app>/maintenance dir (which nginx workers
# cannot read on hardened installs) into nginx's docroot and re-pointing the
# include. The trigger itself needs dokku's full runtime env + root + an nginx
# reload, so we exercise the migration function directly against a sandboxed
# DOKKU_ROOT and docroot - the trigger is a thin loop over this function.

load 'test_helper'

setup() {
  PLUGIN_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  CORE_AVAILABLE_PATH="${PLUGIN_CORE_AVAILABLE_PATH:-/var/lib/dokku/core-plugins/available}"
  [[ -f "$CORE_AVAILABLE_PATH/common/property-functions" ]] ||
    skip "dokku core plugins not available at $CORE_AVAILABLE_PATH"

  # Fully sandboxed paths so the migration never touches the real host.
  SANDBOX_DOKKU_ROOT="${BATS_TEST_TMPDIR}/home-dokku"
  SANDBOX_DATA_ROOT="${BATS_TEST_TMPDIR}/var-www"
  mkdir -p "$SANDBOX_DOKKU_ROOT" "$SANDBOX_DATA_ROOT"
}

# Stage a pre-upgrade layout for $1: assets under DOKKU_ROOT/<app>/maintenance and
# a legacy include whose `root` points at that /home/dokku path.
stage_legacy_app() {
  local app="$1" marker="$2"
  mkdir -p "$SANDBOX_DOKKU_ROOT/$app/maintenance" "$SANDBOX_DOKKU_ROOT/$app/nginx.conf.d"
  echo "$marker" >"$SANDBOX_DOKKU_ROOT/$app/maintenance/maintenance.html"
  cp "$PLUGIN_ROOT/templates/maintenance.conf" "$SANDBOX_DOKKU_ROOT/$app/nginx.conf.d/maintenance.conf"
  sed -i "s,{MAINTENANCE_ROOT},$SANDBOX_DOKKU_ROOT/$app/maintenance," \
    "$SANDBOX_DOKKU_ROOT/$app/nginx.conf.d/maintenance.conf"
}

# Run fn-maintenance-migrate-app in a subshell with the plugin functions sourced
# and the sandboxed paths in the environment.
run_migrate() {
  local app="$1"
  DOKKU_ROOT="$SANDBOX_DOKKU_ROOT" \
    MAINTENANCE_DATA_ROOT="$SANDBOX_DATA_ROOT" \
    MAINTENANCE_PLUGIN_ROOT="$PLUGIN_ROOT" \
    PLUGIN_CORE_AVAILABLE_PATH="$CORE_AVAILABLE_PATH" \
    run bash -c "source '$PLUGIN_ROOT/config'; source '$PLUGIN_ROOT/internal-functions'; fn-maintenance-migrate-app '$app'"
}

@test "migration relocates legacy assets and repoints the include" {
  stage_legacy_app "migrate-app" "legacy-marker-page"

  run_migrate "migrate-app"
  [ "$status" -eq 0 ]

  # legacy dir is gone
  [ ! -d "$SANDBOX_DOKKU_ROOT/migrate-app/maintenance" ]
  # the page (marker intact) now lives in the docroot and is world-readable
  grep -q "legacy-marker-page" "$SANDBOX_DATA_ROOT/migrate-app/maintenance.html"
  local pperms
  pperms="$(stat -c '%A' "$SANDBOX_DATA_ROOT/migrate-app/maintenance.html")"
  [ "${pperms:7:1}" = "r" ]
  # the include now points at the docroot, and the old /home/dokku path is gone
  grep -q "$SANDBOX_DATA_ROOT/migrate-app" "$SANDBOX_DOKKU_ROOT/migrate-app/nginx.conf.d/maintenance.conf"
  ! grep -q "$SANDBOX_DOKKU_ROOT/migrate-app/maintenance" "$SANDBOX_DOKKU_ROOT/migrate-app/nginx.conf.d/maintenance.conf"
}

@test "migration preserves custom pages and extra assets" {
  stage_legacy_app "migrate-custom" "custom-marker-page"
  echo "body {}" >"$SANDBOX_DOKKU_ROOT/migrate-custom/maintenance/style.css"

  run_migrate "migrate-custom"
  [ "$status" -eq 0 ]

  grep -q "custom-marker-page" "$SANDBOX_DATA_ROOT/migrate-custom/maintenance.html"
  [ -f "$SANDBOX_DATA_ROOT/migrate-custom/style.css" ]
}

@test "migration is a no-op when there is nothing to migrate" {
  # no legacy dir staged for this app
  run_migrate "migrate-absent"
  [ "$status" -ne 0 ]
  [ ! -d "$SANDBOX_DATA_ROOT/migrate-absent" ]
}
