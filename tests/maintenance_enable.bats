#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "maintenance:enable fails when no app is specified" {
  run dokku maintenance:enable
  [ "$status" -ne 0 ]
  [[ "$output" == *"Please specify an app to run the command on"* ]]
}

@test "maintenance:enable fails for a nonexistent app" {
  run dokku maintenance:enable nonexistent-app
  [ "$status" -ne 0 ]
  [[ "$output" == *"App nonexistent-app does not exist"* ]]
}

@test "maintenance:enable writes the nginx include and default page" {
  run dokku maintenance:enable "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Enabling maintenance mode for $APP"* ]]
  $SUDO test -f "$(maintenance_conf_path "$APP")"
  $SUDO test -f "$(maintenance_page_path "$APP")"
  $SUDO grep -q "/home/dokku/$APP/maintenance" "$(maintenance_conf_path "$APP")"
  ! $SUDO grep -q '{APP_ROOT}' "$(maintenance_conf_path "$APP")"
}

@test "maintenance:enable carves the acme-challenge path out of the catch-all" {
  run dokku maintenance:enable "$APP"
  [ "$status" -eq 0 ]
  # The catch-all must skip the letsencrypt HTTP-01 path so cert issuance and
  # renewal keep working while maintenance mode is on (issue #10).
  $SUDO grep -q 'acme-challenge' "$(maintenance_conf_path "$APP")"
  # The bare catch-all that swallowed every request must be gone.
  ! $SUDO grep -qE 'location[[:space:]]+~\*[[:space:]]+\^\(\.\*\)\$' "$(maintenance_conf_path "$APP")"
}

@test "maintenance:enable is idempotent" {
  dokku maintenance:enable "$APP"
  run dokku maintenance:enable "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Maintenance mode already enabled"* ]]
}

@test "maintenance:on works as a deprecated alias" {
  run dokku maintenance:on "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deprecated: Please use maintenance:enable"* ]]
  $SUDO test -f "$(maintenance_conf_path "$APP")"
}

@test "maintenance:enable supports the --app flag" {
  run dokku --app "$APP" maintenance:enable
  [ "$status" -eq 0 ]
  $SUDO test -f "$(maintenance_conf_path "$APP")"
}
