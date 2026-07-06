#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "maintenance:enable fails when no app is specified" {
  run dokku maintenance:enable
  [ "$status" -ne 0 ]
  [[ "$output" == *"Please specify an app to run the command on"* ]]
}

@test "maintenance:enable fails for a nonexistent app" {
  run dokku maintenance:enable nonexistent-app
  [ "$status" -ne 0 ]
  [[ "$output" == *"App nonexistent-app does not exist"* ]]
}

@test "maintenance:enable writes the nginx include and default page" {
  run dokku maintenance:enable "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Enabling maintenance mode for $APP"* ]]
  $SUDO test -f "$(maintenance_conf_path "$APP")"
  $SUDO test -f "$(maintenance_page_path "$APP")"
  $SUDO grep -q "$(maintenance_app_dir "$APP")" "$(maintenance_conf_path "$APP")"
  ! $SUDO grep -q '{MAINTENANCE_ROOT}' "$(maintenance_conf_path "$APP")"
}

@test "maintenance:enable serves the page from an nginx-readable location (issue #19)" {
  run dokku maintenance:enable "$APP"
  [ "$status" -eq 0 ]
  # The 403 was caused by nginx workers (www-data/nginx) being unable to
  # traverse /home/dokku (0700 on hardened installs) to read the page. The fix
  # serves it from nginx's docroot instead, so the assets must live outside
  # /home/dokku and be world-traversable/readable.
  local page dir dperms pperms
  page="$(maintenance_page_path "$APP")"
  dir="$(maintenance_app_dir "$APP")"
  [[ "$page" != /home/dokku/* ]]
  # In the `-rwxrwxrwx` string from `stat -c %A`, index 7 is other-read and
  # index 9 is other-execute. The dir must be world-traversable (o+x) and the
  # page world-readable (o+r) for the nginx worker to serve it.
  dperms="$($SUDO stat -c '%A' "$dir")"
  pperms="$($SUDO stat -c '%A' "$page")"
  [ "${dperms:9:1}" = "x" ]
  [ "${pperms:7:1}" = "r" ]
}

@test "maintenance:enable carves the acme-challenge path out of the catch-all" {
  run dokku maintenance:enable "$APP"
  [ "$status" -eq 0 ]
  # The catch-all must skip the letsencrypt HTTP-01 path so cert issuance and
  # renewal keep working while maintenance mode is on (issue #10).
  $SUDO grep -q 'acme-challenge' "$(maintenance_conf_path "$APP")"
  # The bare catch-all that swallowed every request must be gone.
  ! $SUDO grep -qE 'location[[:space:]]+~\*[[:space:]]+\^\(\.\*\)\$' "$(maintenance_conf_path "$APP")"
}

@test "maintenance:enable is idempotent" {
  dokku maintenance:enable "$APP"
  run dokku maintenance:enable "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Maintenance mode already enabled"* ]]
}

@test "maintenance:on works as a deprecated alias" {
  run dokku maintenance:on "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deprecated: Please use maintenance:enable"* ]]
  $SUDO test -f "$(maintenance_conf_path "$APP")"
}

@test "maintenance:enable supports the --app flag" {
  run dokku --app "$APP" maintenance:enable
  [ "$status" -eq 0 ]
  $SUDO test -f "$(maintenance_conf_path "$APP")"
}
