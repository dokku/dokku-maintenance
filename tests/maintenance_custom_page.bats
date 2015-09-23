#!/usr/bin/env bats
load test_helper

create_bad_archive() {
  touch "$DOKKU_ROOT/my_app/bad.html"
  tar cf "$DOKKU_ROOT/my_app/bad.tar" -C "$DOKKU_ROOT/my_app" bad.html
}

create_good_archive() {
  touch "$DOKKU_ROOT/my_app/maintenance.html"
  tar cf "$DOKKU_ROOT/my_app/good.tar" -C "$DOKKU_ROOT/my_app" maintenance.html
}

setup() {
  dokku apps:create my_app >&2
}

teardown() {
  rm "$DOKKU_ROOT/my_app" -rf
}

@test "(maintenance:custom-page) error when there are no arguments" {
  run dokku maintenance:custom-page
  assert_contains "${lines[*]}" "Please specify an app to run the command on"
}

@test "(maintenance:custom-page) error when app does not exist" {
  run dokku maintenance:custom-page non_existing_app
  assert_contains "${lines[*]}" "App non_existing_app does not exist"
}

@test "(maintenance:custom-page) error when tar archive not provided" {
  run dokku maintenance:custom-page my_app
  assert_contains "${lines[*]}" "archive containing at least maintenance.html expected on stdin"
}

@test "(maintenance:custom-page) error when tar archive not containing maintenance.html" {
  create_bad_archive
  run dokku maintenance:custom-page my_app < "$DOKKU_ROOT/my_app/bad.tar"
  assert_contains "${lines[*]}" "archive missing maintenance.html"
}

@test "(maintenance:custom-page) success" {
  create_good_archive
  run dokku maintenance:custom-page my_app < "$DOKKU_ROOT/my_app/good.tar"
  assert_exists "$DOKKU_ROOT/my_app/maintenance/maintenance.html"
  assert_success
}

