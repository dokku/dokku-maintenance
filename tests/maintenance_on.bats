#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create my_app >&2
}

teardown() {
  rm "$DOKKU_ROOT/my_app" -rf
}

@test "(maintenance:on) error when there are no arguments" {
  run dokku maintenance:on
  assert_contains "${lines[*]}" "Please specify an app to run the command on"
}

@test "(maintenance:on) error when app does not exist" {
  run dokku maintenance:on non_existing_app
  assert_contains "${lines[*]}" "App non_existing_app does not exist"
}

@test "(maintenance:on) success" {
  run dokku maintenance:on my_app
  assert_exists "$DOKKU_ROOT/my_app/nginx.conf.d/maintenance.conf"
  assert_exists "$DOKKU_ROOT/my_app/maintenance/maintenance.html"
  assert_success
}

