#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create my_app >&2
}

teardown() {
  rm -rf "$DOKKU_ROOT/my_app"
}

@test "(maintenance:report) error when there are no arguments" {
  run dokku maintenance:report
  assert_contains "${lines[*]}" "Please specify an app to run the command on"
}

@test "(maintenance:report) error when app does not exist" {
  run dokku maintenance:report non_existing_app
  assert_contains "${lines[*]}" "App non_existing_app does not exist"
}

@test "(maintenance:report) success when enabled" {
  dokku maintenance:enable my_app
  run dokku maintenance:report my_app
  assert_contains "${lines[*]}" "true"
}

@test "(maintenance:report) success when disabled" {
  run dokku maintenance:report my_app
  assert_contains "${lines[*]}" "false"
}
