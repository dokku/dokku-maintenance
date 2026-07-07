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

@test "maintenance:report --format json emits a json object" {
  run dokku maintenance:report "$APP" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"enabled":"false"'* ]]

  dokku maintenance:enable "$APP"

  run dokku maintenance:report "$APP" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"enabled":"true"'* ]]
}

@test "maintenance:report --format json includes an empty custom-page-sha256 by default" {
  run dokku maintenance:report "$APP" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"custom-page-sha256":""'* ]]
}

@test "maintenance:report --format json includes the checksum after a custom page upload" {
  local tarball="${BATS_TEST_TMPDIR}/good.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page"
  dokku maintenance:custom-page "$APP" <"$tarball"

  run dokku maintenance:report "$APP" --format json
  [ "$status" -eq 0 ]
  local sha
  sha="$(echo "$output" | jq -r '.["custom-page-sha256"]')"
  [[ "$sha" =~ ^[0-9a-f]{64}$ ]]
}

@test "maintenance:report --maintenance-custom-page-sha256 prints just the value" {
  local tarball="${BATS_TEST_TMPDIR}/good.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page"
  dokku maintenance:custom-page "$APP" <"$tarball"

  run dokku maintenance:report "$APP" --maintenance-custom-page-sha256
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9a-f]{64}$ ]]
}

@test "maintenance:report lists custom-page-sha256 among valid flags" {
  run dokku maintenance:report "$APP" --invalid-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"--maintenance-custom-page-sha256"* ]]
}

@test "maintenance:report --format json rejects an info flag" {
  run dokku maintenance:report "$APP" --format json --maintenance-enabled
  [ "$status" -ne 0 ]
  [[ "$output" == *"--format flag cannot be specified when specifying an info flag"* ]]
}

@test "maintenance:report --global --format json returns a json object" {
  run dokku maintenance:report --global --format json
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
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
