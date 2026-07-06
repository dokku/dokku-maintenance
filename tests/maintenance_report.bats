#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "maintenance:report fails for a nonexistent app" {
  run dokku maintenance:report nonexistent-app
  [ "$status" -ne 0 ]
  [[ "$output" == *"App nonexistent-app does not exist"* ]]
}

@test "maintenance:report shows disabled by default" {
  run dokku maintenance:report "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$APP maintenance information"* ]]
  [[ "$output" == *"Maintenance enabled"* ]]
  [[ "$output" == *"false"* ]]
}

@test "maintenance:report shows enabled after enable" {
  dokku maintenance:enable "$APP"
  run dokku maintenance:report "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"true"* ]]
}

@test "maintenance:report --maintenance-enabled prints just the value" {
  run dokku maintenance:report "$APP" --maintenance-enabled
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]

  dokku maintenance:enable "$APP"

  run dokku maintenance:report "$APP" --maintenance-enabled
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "maintenance:report rejects an invalid flag" {
  run dokku maintenance:report "$APP" --invalid-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid flag passed, valid flags"* ]]
  [[ "$output" == *"--maintenance-enabled"* ]]
}

@test "maintenance:report without arguments reports all apps" {
  run dokku maintenance:report
  [ "$status" -eq 0 ]
  [[ "$output" == *"$APP maintenance information"* ]]
}

@test "dokku report includes a maintenance section" {
  run dokku report "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"maintenance information"* ]]
}
