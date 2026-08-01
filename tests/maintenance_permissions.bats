#!/usr/bin/env bats
# Regression for issue #33: running dokku from a working directory the invoking
# (non-root) user cannot enter - e.g. a 0700 home dir owned by someone else -
# made GNU find in fn-maintenance-fix-permissions abort with "Failed to restore
# initial working directory". find changes into the target dir to traverse it
# and then restores the process's original working directory; when that dir is
# unreadable the restore fails, find exits non-zero, and (under set -eo pipefail)
# maintenance:enable aborts.
#
# The bug only manifests for a NON-root process (root bypasses the directory
# permission check), so this test drops to the unprivileged `nobody` user while
# leaving it in an inaccessible working directory - exactly the reported
# condition. Everything sourced/traversed is staged world-readable so it does
# not depend on the dokku install's own permissions.

load 'test_helper'

setup() {
  PLUGIN_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  CORE_AVAILABLE_PATH="${PLUGIN_CORE_AVAILABLE_PATH:-/var/lib/dokku/core-plugins/available}"
  # Reproducing the bug requires root to cd into a dir it then drops privileges
  # out of; native mode runs as the unprivileged runner and cannot set this up.
  [[ "$(id -u)" -eq 0 ]] ||
    skip "requires root to drop into a working directory the target user cannot access"
  command -v setpriv >/dev/null 2>&1 || skip "setpriv (util-linux) is required"
  id -u nobody >/dev/null 2>&1 || skip "the nobody user is required"

  # Stage outside BATS_TEST_TMPDIR: bats creates that tree mode 0700, so nobody
  # could not traverse into it. A mktemp dir under /tmp (1777) made world-
  # traversable lets the dropped-privilege process reach the staged files.
  WORK="$(mktemp -d)"
  chmod 755 "$WORK"
}

teardown() {
  # WORK is unset when setup() skipped before staging (e.g. native mode). Guard
  # with an `if` so teardown always returns 0 - a bare `[[ ]] && rm` would return
  # the false test's non-zero status and fail the (skipped) test.
  if [[ -n "${WORK:-}" ]]; then
    rm -rf "$WORK"
  fi
}

# Run fn-maintenance-fix-permissions as `nobody` with its working directory set
# to a dir `nobody` cannot enter. Echoes the exit status and captured output.
run_fix_permissions_from_inaccessible_cwd() {
  local target="$1"

  # A stub property-functions keeps the source at the top of internal-functions
  # self-contained (fix-permissions never touches the property store), so the
  # test does not depend on the dokku core plugins being nobody-readable.
  mkdir -p "$WORK/core/common"
  printf '#!/usr/bin/env bash\n' >"$WORK/core/common/property-functions"
  cp "$PLUGIN_ROOT/internal-functions" "$WORK/internal-functions"
  chmod -R a+rX "$WORK/core" "$WORK/internal-functions"

  # A working directory owned by root, mode 0700: `nobody` cannot enter it.
  local restricted="$WORK/restricted"
  mkdir -p "$restricted"
  chmod 700 "$restricted"
  chown root:root "$restricted"

  local nobody_gid
  nobody_gid="$(id -g nobody)"

  # cd into it as root, then drop to nobody keeping that directory as the CWD.
  cd "$restricted"
  run setpriv --reuid=nobody --regid="$nobody_gid" --clear-groups \
    env PLUGIN_CORE_AVAILABLE_PATH="$WORK/core" \
    bash -c "source '$WORK/internal-functions'; fn-maintenance-fix-permissions '$target'"
  cd /
}

@test "fn-maintenance-fix-permissions succeeds from an inaccessible working directory (issue #33)" {
  # A target dir owned by the unprivileged user, mirroring the dokku-owned
  # /var/www/dokku-maintenance/<app> that the real helper operates on.
  local target="$WORK/app"
  mkdir -p "$target/assets"
  echo '<h1>down for maintenance</h1>' >"$target/maintenance.html"
  echo 'body { color: #333; }' >"$target/assets/style.css"
  chmod -R u+rwX "$target"
  chown -R nobody:"$(id -g nobody)" "$target"

  run_fix_permissions_from_inaccessible_cwd "$target"

  [ "$status" -eq 0 ]
  [[ "$output" != *"working directory"* ]]
  # The fix still applies the intended perms: 0755 dirs, 0644 files.
  [ "$(stat -c '%a' "$target")" = "755" ]
  [ "$(stat -c '%a' "$target/assets")" = "755" ]
  [ "$(stat -c '%a' "$target/maintenance.html")" = "644" ]
  [ "$(stat -c '%a' "$target/assets/style.css")" = "644" ]
}
