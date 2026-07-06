#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "maintenance:custom-page fails when no app is specified" {
  run dokku maintenance:custom-page
  [ "$status" -ne 0 ]
  [[ "$output" == *"Please specify an app to run the command on"* ]]
}

@test "maintenance:custom-page fails for a nonexistent app" {
  run dokku maintenance:custom-page nonexistent-app
  [ "$status" -ne 0 ]
  [[ "$output" == *"App nonexistent-app does not exist"* ]]
}

@test "maintenance:custom-page fails when stdin is not a tar archive" {
  run dokku maintenance:custom-page "$APP" </dev/null
  [ "$status" -ne 0 ]
  ! $SUDO test -f "$(maintenance_page_path "$APP")"
}

@test "maintenance:custom-page fails when the tarball lacks maintenance.html" {
  local tarball="${BATS_TEST_TMPDIR}/bad.tar"
  make_tarball "$tarball" "bad.html=<html>bad</html>"
  run dokku maintenance:custom-page "$APP" <"$tarball"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing maintenance.html"* ]]
  ! $SUDO test -f "$(maintenance_page_path "$APP")"
}

@test "maintenance:custom-page imports a tarball containing maintenance.html" {
  local tarball="${BATS_TEST_TMPDIR}/good.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page"
  run dokku maintenance:custom-page "$APP" <"$tarball"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Importing custom maintenance page"* ]]
  $SUDO grep -q "maintest-marker-page" "$(maintenance_page_path "$APP")"
}

@test "maintenance:custom-page imports extra files alongside maintenance.html" {
  local tarball="${BATS_TEST_TMPDIR}/extra.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page" "style.css=body {}"
  run dokku maintenance:custom-page "$APP" <"$tarball"
  [ "$status" -eq 0 ]
  $SUDO test -f "$(maintenance_page_path "$APP")"
  $SUDO test -f "$(maintenance_app_dir "$APP")/style.css"
}

@test "maintenance:custom-page writes an nginx-readable page (issue #19)" {
  local tarball="${BATS_TEST_TMPDIR}/perms.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page"
  run dokku maintenance:custom-page "$APP" <"$tarball"
  [ "$status" -eq 0 ]
  local page pperms
  page="$(maintenance_page_path "$APP")"
  [[ "$page" != /home/dokku/* ]]
  # other-read bit (index 7 of the `-rwxrwxrwx` string) must be set
  pperms="$($SUDO stat -c '%A' "$page")"
  [ "${pperms:7:1}" = "r" ]
}

@test "maintenance:enable preserves a previously imported custom page" {
  local tarball="${BATS_TEST_TMPDIR}/custom.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page"
  dokku maintenance:custom-page "$APP" <"$tarball"
  run dokku maintenance:enable "$APP"
  [ "$status" -eq 0 ]
  $SUDO grep -q "maintest-marker-page" "$(maintenance_page_path "$APP")"
}

@test "maintenance:custom-page replaces the default page after enable" {
  dokku maintenance:enable "$APP"
  local tarball="${BATS_TEST_TMPDIR}/replace.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page"
  run dokku maintenance:custom-page "$APP" <"$tarball"
  [ "$status" -eq 0 ]
  $SUDO grep -q "maintest-marker-page" "$(maintenance_page_path "$APP")"
}
