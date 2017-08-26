#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create my_app >&2
  dokku maintenance:on my_app >&2
}

teardown() {
  rm -rf "$DOKKU_ROOT/my_app"
}

@test "(maintenance:off) error when there are no arguments" {
  run dokku maintenance:off
  assert_contains "${lines[*]}" "Please specify an app to run the command on"
}

@test "(maintenance:off) error when app does not exist" {
  run dokku maintenance:off non_existing_app
  assert_contains "${lines[*]}" "App non_existing_app does not exist"
}

@test "(maintenance:off) success" {
  run dokku maintenance:off my_app
  [[ ! -f $DOKKU_ROOT/my_app/nginx.conf.d/maintenance.conf ]]
  assert_success
}

