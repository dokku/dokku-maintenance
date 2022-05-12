#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create my_app >&2
}

teardown() {
  rm -rf "$DOKKU_ROOT/my_app"
}

@test "(maintenance:enable) error when there are no arguments" {
  run dokku maintenance:enable
  assert_contains "${lines[*]}" "Please specify an app to run the command on"
}

@test "(maintenance:enable) error when app does not exist" {
  run dokku maintenance:enable non_existing_app
  assert_contains "${lines[*]}" "App non_existing_app does not exist"
}

@test "(maintenance:enable) success" {
  run dokku maintenance:enable my_app
  assert_exists "$DOKKU_ROOT/my_app/nginx.conf.d/maintenance.conf"
  assert_exists "$DOKKU_ROOT/my_app/maintenance/maintenance.html"
  assert_success
}

