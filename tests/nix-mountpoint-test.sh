#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CLEANUP="$ROOT/build_files/70-cleanup.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Run only the /nix block, re-rooted at a fake tree.
sed -n '/^# Composefs keeps/,$p' "$CLEANUP" |
    sed -E "s#(^| )/(nix|usr/local)#\1$WORK/root/\2#g" > "$WORK/block.sh"
grep -q 'mkdir' "$WORK/block.sh" || fail "no /nix block in 70-cleanup.sh"

fake_root() {
    rm -rf "$WORK/root"
    mkdir -p "$WORK/root/usr/local/bin" "$WORK/root/usr/local/share/man/man1" \
        "$WORK/root/usr/local/share/applications"
    : > "$WORK/root/usr/local/share/applications/mimeinfo.cache"
}

fake_root
bash -euo pipefail "$WORK/block.sh" || fail "block failed on a stock /usr/local"
[[ -d $WORK/root/nix && -z $(ls -A "$WORK/root/nix") ]] || fail "/nix is not an empty directory"
[[ $(readlink "$WORK/root/usr/local") == ../var/usrlocal ]] || fail "/usr/local does not link to ../var/usrlocal"

# Real content in /usr/local would vanish behind the link, so the build must stop.
fake_root
: > "$WORK/root/usr/local/bin/tool"
if bash -euo pipefail "$WORK/block.sh" 2>/dev/null; then
    fail "block silently dropped /usr/local/bin/tool"
fi

echo "nix-mountpoint-test: ok"
