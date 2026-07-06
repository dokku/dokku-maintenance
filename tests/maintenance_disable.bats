#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
  dokku maintenance:enable "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "maintenance:disable fails when no app is specified" {
  run dokku maintenance:disable
  [ "$status" -ne 0 ]
  [[ "$output" == *"Please specify an app to run the command on"* ]]
}

@test "maintenance:disable fails for a nonexistent app" {
  run dokku maintenance:disable nonexistent-app
  [ "$status" -ne 0 ]
  [[ "$output" == *"App nonexistent-app does not exist"* ]]
}

@test "maintenance:disable removes the nginx include" {
  run dokku maintenance:disable "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Disabling maintenance mode for $APP"* ]]
  $SUDO test ! -f "$(maintenance_conf_path "$APP")"
}

@test "maintenance:disable is idempotent" {
  dokku maintenance:disable "$APP"
  run dokku maintenance:disable "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Maintenance mode already disabled"* ]]
}

@test "maintenance:disable leaves the maintenance page in place" {
  run dokku maintenance:disable "$APP"
  [ "$status" -eq 0 ]
  $SUDO test -f "$(maintenance_page_path "$APP")"
}

@test "maintenance:off works as a deprecated alias" {
  run dokku maintenance:off "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deprecated: Please use maintenance:disable"* ]]
  $SUDO test ! -f "$(maintenance_conf_path "$APP")"
}

@test "maintenance:disable supports the --app flag" {
  run dokku --app "$APP" maintenance:disable
  [ "$status" -eq 0 ]
  $SUDO test ! -f "$(maintenance_conf_path "$APP")"
}
