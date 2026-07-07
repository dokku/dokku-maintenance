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

@test "maintenance:custom-page records a reproducible content checksum" {
  local stage="${BATS_TEST_TMPDIR}/page"
  mkdir -p "$stage"
  echo "maintest-marker-page" >"$stage/maintenance.html"
  echo "body {}" >"$stage/style.css"
  local tarball="${BATS_TEST_TMPDIR}/page.tar"
  tar -cf "$tarball" -C "$stage" .

  dokku maintenance:custom-page "$APP" <"$tarball"

  run dokku maintenance:report "$APP" --maintenance-custom-page-sha256
  [ "$status" -eq 0 ]
  [ "$output" = "$(page_checksum "$stage")" ]
}

@test "maintenance:custom-page prunes files from a previous upload" {
  local first="${BATS_TEST_TMPDIR}/first.tar"
  make_tarball "$first" "maintenance.html=first-page" "style.css=body {}"
  dokku maintenance:custom-page "$APP" <"$first"
  $SUDO test -f "$(maintenance_app_dir "$APP")/style.css"

  local stage="${BATS_TEST_TMPDIR}/second"
  mkdir -p "$stage"
  echo "second-page" >"$stage/maintenance.html"
  local second="${BATS_TEST_TMPDIR}/second.tar"
  tar -cf "$second" -C "$stage" .
  dokku maintenance:custom-page "$APP" <"$second"

  # the stale asset is gone and the stored page is exactly the new upload
  ! $SUDO test -f "$(maintenance_app_dir "$APP")/style.css"
  run dokku maintenance:report "$APP" --maintenance-custom-page-sha256
  [ "$status" -eq 0 ]
  [ "$output" = "$(page_checksum "$stage")" ]
}

@test "maintenance:custom-page-export fails when no app is specified" {
  run dokku maintenance:custom-page-export
  [ "$status" -ne 0 ]
  [[ "$output" == *"Please specify an app to run the command on"* ]]
}

@test "maintenance:custom-page-export fails for a nonexistent app" {
  run dokku maintenance:custom-page-export nonexistent-app
  [ "$status" -ne 0 ]
  [[ "$output" == *"App nonexistent-app does not exist"* ]]
}

@test "maintenance:custom-page-export warns and emits an empty archive when no custom page is set" {
  local out="${BATS_TEST_TMPDIR}/out.tar"
  local err="${BATS_TEST_TMPDIR}/err.log"
  # redirect the streams to files so the binary archive does not reach $output
  run bash -c "dokku maintenance:custom-page-export '$APP' >'$out' 2>'$err'"
  [ "$status" -eq 0 ]
  grep -q "nothing to export" "$err"
  # a valid but empty archive lists no entries
  [ -z "$(tar -tf "$out")" ]
}

@test "maintenance:custom-page-export streams the stored custom page as a tarball" {
  local tarball="${BATS_TEST_TMPDIR}/in.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page" "style.css=body {}"
  dokku maintenance:custom-page "$APP" <"$tarball"

  local out="${BATS_TEST_TMPDIR}/out.tar"
  run bash -c "dokku maintenance:custom-page-export '$APP' >'$out'"
  [ "$status" -eq 0 ]

  local extract="${BATS_TEST_TMPDIR}/extract"
  mkdir -p "$extract"
  tar -xf "$out" -C "$extract"
  grep -q "maintest-marker-page" "$extract/maintenance.html"
  [ -f "$extract/style.css" ]
}

@test "maintenance:custom-page-export round-trips through custom-page into another app" {
  local tarball="${BATS_TEST_TMPDIR}/in.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page" "style.css=body {}"
  dokku maintenance:custom-page "$APP" <"$tarball"

  local sha1
  sha1="$(dokku maintenance:report "$APP" --maintenance-custom-page-sha256)"

  local out="${BATS_TEST_TMPDIR}/out.tar"
  run bash -c "dokku maintenance:custom-page-export '$APP' >'$out'"
  [ "$status" -eq 0 ]

  local app2
  app2="$(new_app_name)"
  create_app "$app2"
  dokku maintenance:custom-page "$app2" <"$out"
  local sha2
  sha2="$(dokku maintenance:report "$app2" --maintenance-custom-page-sha256)"
  cleanup_app "$app2"

  # exporting then re-importing reproduces the same content checksum
  [[ "$sha1" =~ ^[0-9a-f]{64}$ ]]
  [ "$sha1" = "$sha2" ]
}

@test "maintenance:custom-page-remove clears the checksum and restores the default page" {
  dokku maintenance:enable "$APP"
  local tarball="${BATS_TEST_TMPDIR}/custom.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page"
  dokku maintenance:custom-page "$APP" <"$tarball"

  run dokku maintenance:custom-page-remove "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removing custom maintenance page"* ]]

  # the checksum is cleared
  run dokku maintenance:report "$APP" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"custom-page-sha256":""'* ]]

  # the default page is served again (custom marker gone, default content back)
  $SUDO test -f "$(maintenance_page_path "$APP")"
  ! $SUDO grep -q "maintest-marker-page" "$(maintenance_page_path "$APP")"
  $SUDO grep -q "Application Offline for Maintenance" "$(maintenance_page_path "$APP")"
}

@test "maintenance:custom-page-remove removes the page dir when disabled" {
  local tarball="${BATS_TEST_TMPDIR}/custom.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page"
  dokku maintenance:custom-page "$APP" <"$tarball"

  run dokku maintenance:custom-page-remove "$APP"
  [ "$status" -eq 0 ]
  ! $SUDO test -d "$(maintenance_app_dir "$APP")"

  run dokku maintenance:report "$APP" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"custom-page-sha256":""'* ]]
}

@test "maintenance:custom-page-remove is a no-op when no custom page is set" {
  run dokku maintenance:custom-page-remove "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No custom maintenance page set"* ]]
}

@test "destroying an app removes its stored custom page (post-delete)" {
  local tarball="${BATS_TEST_TMPDIR}/good.tar"
  make_tarball "$tarball" "maintenance.html=maintest-marker-page"
  dokku maintenance:custom-page "$APP" <"$tarball"
  $SUDO test -d "$(maintenance_app_dir "$APP")"

  dokku --force apps:destroy "$APP"
  ! $SUDO test -d "$(maintenance_app_dir "$APP")"
}
