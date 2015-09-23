#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create my_app >&2
}

teardown() {
  rm "$DOKKU_ROOT/my_app" -rf
}

@test "(maintenance) error when there are no arguments" {
  run dokku maintenance
  assert_contains "${lines[*]}" "Please specify an app to run the command on"
}

@test "(maintenance) error when app does not exist" {
  run dokku maintenance non_existing_app
  assert_contains "${lines[*]}" "App non_existing_app does not exist"
}

@test "(maintenance) success when on" {
  dokku maintenance:on my_app
  run dokku maintenance my_app
  assert_contains "${lines[*]}" "on"
}

@test "(maintenance) success when off" {
  run dokku maintenance my_app
  assert_contains "${lines[*]}" "off"
}
