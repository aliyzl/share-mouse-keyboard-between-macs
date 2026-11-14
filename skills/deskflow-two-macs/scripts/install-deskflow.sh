#!/usr/bin/env bash
# Download, verify and install Deskflow on macOS.
#
# Every check that was done by hand during the original setup is done here, and the
# script stops at the first one that fails:
#   1. the DMG's SHA-256 matches both the release's sums.txt and GitHub's asset digest;
#   2. the DMG is a notarized Developer ID image (Gatekeeper accepts it);
#   3. the app inside is signed by the expected team and passes a strict deep verify.
#
# Usage: install-deskflow.sh [--version 1.27.0 | --latest] [--download-only] [--force]
#   --version        release tag without the leading "v" (default: 1.27.0, the release verified here)
#   --latest         the newest release instead; its settings format may differ from the one documented
#   --download-only  verify everything but do not copy into /Applications
#   --force          replace an existing /Applications/Deskflow.app
# Needs: curl, and python3 from the Xcode Command Line Tools (xcode-select --install).
set -euo pipefail

VERIFIED_VERSION="1.27.0"
EXPECTED_TEAM_ID="5QCJCX8C37"   # Deskflow's Developer ID team, seen on 1.27.0
REPO="deskflow/deskflow"
APP_DEST="/Applications/Deskflow.app"

version="$VERIFIED_VERSION" download_only=0 force=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) version="${2:?--version needs a value}"; shift 2 ;;
    --latest) version=""; shift ;;
    --download-only) download_only=1; shift ;;
    --force) force=1; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

say()  { printf '==> %s\n' "$*"; }
fail() { printf 'FAILED: %s\n' "$*" >&2; exit 1; }

# The hardware, not the shell: uname -m says x86_64 inside a Rosetta terminal on Apple Silicon.
if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" == "1" ]]; then arch="arm64"; else arch="x86_64"; fi

xcode-select -p >/dev/null 2>&1 || fail "python3 needs the Xcode Command Line Tools: run xcode-select --install"
if [[ "$version" != "$VERIFIED_VERSION" ]]; then
  echo "note: this repository was verified with $VERIFIED_VERSION; ${version:-the latest release} may use other settings" >&2
fi

# Refuse early, before any download, if installing would clobber or race a running copy.
if [[ $download_only -eq 0 ]]; then
  if [[ -e "$APP_DEST" && $force -eq 0 ]]; then
    fail "$APP_DEST already exists; quit Deskflow and re-run with --force to replace it"
  fi
  if pgrep -f "$APP_DEST/Contents/MacOS/" >/dev/null; then
    fail "Deskflow is running; quit it first (kill -TERM its processes; AppleScript quit is refused)"
  fi
fi

if [[ -n "$version" ]]; then api="https://api.github.com/repos/$REPO/releases/tags/v$version"
else api="https://api.github.com/repos/$REPO/releases/latest"; fi

work="$(mktemp -d)"
mnt=""
cleanup() {
  [[ -n "$mnt" ]] && hdiutil detach "$mnt" -quiet 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

say "Reading release metadata from GitHub"
curl -fsSL "$api" -o "$work/release.json" || fail "could not read $api"

# Pick the macOS DMG for this architecture and sums.txt, with GitHub's own digest.
read -r tag dmg_name dmg_url dmg_digest sums_url < <(/usr/bin/python3 -I - "$work/release.json" "$arch" <<'PY'
import json, sys
rel = json.load(open(sys.argv[1])); arch = sys.argv[2]
assets = {a["name"]: a for a in rel.get("assets", [])}
dmg = next((a for n, a in assets.items() if n.endswith(f"-macos-{arch}.dmg")), None)
sums = assets.get("sums.txt")
if not dmg or not sums:
    sys.exit("release has no macOS %s DMG or no sums.txt" % arch)
digest = (dmg.get("digest") or "none").removeprefix("sha256:")
print(rel["tag_name"], dmg["name"], dmg["browser_download_url"], digest, sums["browser_download_url"])
PY
) || fail "could not find a macOS $arch DMG in the release"
say "Release $tag, asset $dmg_name"

say "Downloading"
curl -fsSL "$dmg_url" -o "$work/$dmg_name" || fail "DMG download failed"
curl -fsSL "$sums_url" -o "$work/sums.txt" || fail "sums.txt download failed"

say "Checking SHA-256"
actual="$(shasum -a 256 "$work/$dmg_name" | awk '{print $1}')"
listed="$(awk -v f="$dmg_name" '$2 == f || $2 == "*"f {print $1}' "$work/sums.txt")"
[[ -n "$listed" ]] || fail "$dmg_name is not listed in sums.txt"
[[ "$actual" == "$listed" ]] || fail "hash differs from sums.txt ($actual vs $listed)"
matched="sums.txt"
if [[ "$dmg_digest" != "none" ]]; then
  [[ "$actual" == "$dmg_digest" ]] || fail "hash differs from GitHub's asset digest"
  matched="sums.txt and GitHub's asset digest"
fi
echo "    sha256 $actual matches $matched"

say "Checking the DMG's notarization"
spctl -a -t open --context context:primary-signature -vv "$work/$dmg_name" 2>&1 | sed 's/^/    /' || true
spctl -a -t open --context context:primary-signature "$work/$dmg_name" 2>/dev/null \
  || fail "Gatekeeper rejects the DMG"

say "Mounting (the DMG shows the GPL licence; it is accepted here)"
# The image carries a Software License Agreement. Without an answer hdiutil prints
# "attach canceled", so the licence (GPL-2.0) is accepted on stdin. `yes` dies of SIGPIPE
# when hdiutil stops reading, so pipefail is off inside this one substitution.
mnt="$(set +o pipefail
       yes | env PAGER=cat hdiutil attach -nobrowse -readonly -noautoopen "$work/$dmg_name" 2>/dev/null \
         | awk -F'\t' '/\/Volumes\//{print $NF}')"
[[ -d "$mnt/Deskflow.app" ]] || fail "Deskflow.app not found in the image"

say "Checking the app's signature"
codesign --verify --deep --strict "$mnt/Deskflow.app" || fail "codesign verification failed"
team="$(codesign -dv "$mnt/Deskflow.app" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2}')"
[[ "$team" == "$EXPECTED_TEAM_ID" ]] || fail "unexpected signing team '$team' (expected $EXPECTED_TEAM_ID)"
spctl -a -t exec "$mnt/Deskflow.app" 2>/dev/null || fail "Gatekeeper rejects the app"
echo "    signed by team $team, notarized"

if [[ $download_only -eq 1 ]]; then
  say "All checks passed (--download-only: nothing installed)"
  exit 0
fi

say "Installing to $APP_DEST"
rm -rf "$APP_DEST"
ditto "$mnt/Deskflow.app" "$APP_DEST"
codesign --verify --deep --strict "$APP_DEST" || fail "installed copy fails verification"
# Register with LaunchServices; without this, `open` failed once with error -10810.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DEST"

say "Installed $("$APP_DEST/Contents/MacOS/deskflow-core" --version 2>/dev/null | head -1)"
