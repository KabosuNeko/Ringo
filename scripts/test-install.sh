#!/bin/sh
# End-to-end test of install.sh in a throwaway sandbox: no real $HOME, no
# display server, no root, no network. Run from anywhere: sh scripts/test-install.sh
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REAL_HOME="$HOME"
FAKE_HOME="$(mktemp -d)"; OTHER_HOME="$(mktemp -d)"
STUB_BIN="$(mktemp -d)"; LOG="$(mktemp)"
cleanup() { rm -rf "$FAKE_HOME" "$OTHER_HOME" "$STUB_BIN" "$LOG"; }
trap cleanup EXIT
fail() { printf 'FAIL %s\n' "$1"; exit 1; }
pass() { printf 'ok   %s\n' "$1"; }
links() { find "$1" -type l | wc -l | tr -d ' '; }
stamp() { [ -d "$1" ] && stat -c %Y "$1" || echo absent; }

# run_install <home> [args...]: run install.sh with $HOME overridden, set $STATUS.
run_install() {
    home="$1"; shift
    set +e
    HOME="$home" sh "$REPO_DIR/install.sh" "$@" > "$LOG" 2>&1
    STATUS=$?
    set -e
}

BACKEND="$REAL_HOME/.config/ringo-shell/IslandBackend"
real_before="$(stamp "$BACKEND/.backup")"

# Stub the machine-facing commands: they only have to succeed, changing nothing.
for tool in yay sudo systemctl gsettings xdg-mime fc-list; do
    printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/$tool"
    chmod +x "$STUB_BIN/$tool"
done
PATH="$STUB_BIN:$PATH"; export PATH

# install.sh downloads the Maple Mono NF font from the GitHub API. This stub
# keeps the test offline and makes the font step take its "no download
# available" path, which must not fail the install.
printf '#!/bin/sh\nexit 1\n' > "$STUB_BIN/curl"
chmod +x "$STUB_BIN/curl"

# 2. a target file stow does not own must abort before anything is linked.
mkdir -p "$FAKE_HOME/.config/niri"
printf 'hand written config\n' > "$FAKE_HOME/.config/niri/config.kdl"
run_install "$FAKE_HOME" --yes --non-interactive --profile core
[ "$STATUS" -eq 1 ] || fail "occupied \$HOME should abort with status 1 (got $STATUS)"
pass "occupied \$HOME aborts with status 1"
grep -q 'Stow would refuse to replace files already in \$HOME' "$LOG" || fail "stow pre-flight message missing"
pass "stow pre-flight message printed"
[ "$(links "$FAKE_HOME")" -eq 0 ] || fail "symlinks were created before the abort"
pass "zero symlinks in \$HOME after the abort"

# 3. free target: the core install really deploys everything.
rm -f "$FAKE_HOME/.config/niri/config.kdl"
run_install "$FAKE_HOME" --yes --non-interactive --profile core
[ "$STATUS" -eq 0 ] || fail "core install should succeed (status $STATUS)"
pass "core install exits 0"
expected="$(find "$REPO_DIR/home" -type f | wc -l | tr -d ' ')"
[ "$(links "$FAKE_HOME")" -eq "$expected" ] || fail "expected $expected symlinks, got $(links "$FAKE_HOME")"
pass "$expected symlinks deployed into \$HOME"
[ -e "$FAKE_HOME/.config/ringo-shell/IslandBackend/libIslandBackend.so" ] || fail "IslandBackend/libIslandBackend.so missing"
pass "IslandBackend/libIslandBackend.so installed"

# 4. the font step runs (--yes), cannot download (curl stub) and must stay soft:
grep -q "Install the MapleMono-NF-unhinted.zip release into" "$LOG" ||
    fail "font step should print the manual hint when the download is unavailable"
pass "failed font download falls back to the manual hint"
[ ! -e "$FAKE_HOME/.local/share/fonts" ] ||
    fail "font step wrote font files without a successful download"
pass "no font files written when the download fails"

# 5. --rollback really restores the snapshot, not just reports success.
FAKE_BACKEND="$FAKE_HOME/.config/ringo-shell/IslandBackend"
printf 'rollback-sentinel\n' > "$FAKE_BACKEND/.backup/qmldir"
run_install "$FAKE_HOME" --rollback
[ "$STATUS" -eq 0 ] || fail "--rollback with a snapshot should exit 0 (got $STATUS)"
[ "$(cat "$FAKE_BACKEND/qmldir")" = "rollback-sentinel" ] || fail "--rollback did not restore qmldir"
pass "--rollback restores a backup file"

# 6. rollback without a snapshot fails cleanly.
run_install "$OTHER_HOME" --rollback
[ "$STATUS" -eq 1 ] || fail "--rollback without a backup should exit 1 (got $STATUS)"
pass "--rollback without a backup exits 1"
grep -q 'No backend backup found' "$LOG" || fail "rollback error message missing"
pass "'No backend backup found' printed"

# 7. dry run changes nothing and succeeds.
run_install "$OTHER_HOME" --dry-run --non-interactive --profile core
[ "$STATUS" -eq 0 ] || fail "--dry-run should exit 0 (status $STATUS)"
pass "--dry-run --non-interactive --profile core exits 0"

# 8. the real $HOME was never touched by any of the above.
[ "$(stamp "$BACKEND/.backup")" = "$real_before" ] || fail "real \$HOME backend backup changed"
pass "real \$HOME untouched"

echo "all checks passed"
