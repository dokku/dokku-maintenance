#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create my_app >&2
  dokku maintenance:enable my_app >&2
}

teardown() {
  rm -rf "$DOKKU_ROOT/my_app"
}

@test "(maintenance:disable) error when there are no arguments" {
  run dokku maintenance:disable
  assert_contains "${lines[*]}" "Please specify an app to run the command on"
}

@test "(maintenance:disable) error when app does not exist" {
  run dokku maintenance:disable non_existing_app
  assert_contains "${lines[*]}" "App non_existing_app does not exist"
}

@test "(maintenance:disable) success" {
  run dokku maintenance:disable my_app
  [[ ! -f $DOKKU_ROOT/my_app/nginx.conf.d/maintenance.conf ]]
  assert_success
}

