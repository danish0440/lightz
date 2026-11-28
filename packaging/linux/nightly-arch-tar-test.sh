#!/usr/bin/env bash
# Validate the staged Arch launcher without building or opening LightZ.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
stage="$work/source"
dst="$work/dist"
base=lightz-0.0.1-nightly.1-linux-x86_64
mkdir -p "$stage/bin" "$dst" "$work/extract"

# A local argv/env recorder stands in for the compiled binaries. It never opens a UI.
cat >"$stage/bin/lightz" <<'RECORDER'
#!/bin/sh
printf 'CONFIG=<%s>\n' "${LIGHTZ_CONFIG_DIR-<unset>}"
printf 'LIBRARY=<%s>\n' "${LIGHTZ_LIBRARY-<unset>}"
for arg in "$@"; do
  printf '<%s>\n' "$arg"
done
RECORDER
chmod 755 "$stage/bin/lightz"
cp "$stage/bin/lightz" "$stage/bin/lightz-cli"
# A minimal FHS share tree, so the Nightly desktop/metainfo/icon rewrite is exercised.
mkdir -p "$stage/share/applications" "$stage/share/metainfo" "$stage/share/icons/hicolor/256x256/apps"
cat >"$stage/share/applications/com.pintaz.lightz.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=LightZ
Exec=lightz %F
Icon=com.pintaz.lightz
StartupWMClass=com.pintaz.lightz
MimeType=image/jpeg;
DESKTOP
cat >"$stage/share/metainfo/com.pintaz.lightz.metainfo.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>com.pintaz.lightz</id>
  <name>LightZ</name>
  <launchable type="desktop-id">com.pintaz.lightz.desktop</launchable>
  <icon type="stock">com.pintaz.lightz</icon>
  <provides><binary>lightz</binary></provides>
</component>
XML
: >"$stage/share/icons/hicolor/256x256/apps/com.pintaz.lightz.png"

bash "$HERE/nightly-arch-tar.sh" "$stage" "$work/stage" "$dst" "$base"
tar -xzf "$dst/$base.tar.gz" -C "$work/extract"
bin="$work/extract/$base/bin"
# Simulate the existing Arch bin-tree copy and public launcher rename.
mkdir -p "$work/installed"
cp -R "$bin" "$work/installed/bin"
bin="$work/installed/bin"
mv "$bin/lightz" "$bin/lightz-nightly"
mv "$bin/lightz-cli" "$bin/lightz-nightly-cli"

# The packager installs the tree as it is: no stable id may be left to rename.
nightly_id=com.pintaz.lightz.nightly-v1
share="$work/extract/$base/share"
test -f "$share/applications/$nightly_id.desktop"
test ! -e "$share/applications/com.pintaz.lightz.desktop"
grep -qx "StartupWMClass=$nightly_id" "$share/applications/$nightly_id.desktop"
grep -qx "Icon=$nightly_id" "$share/applications/$nightly_id.desktop"
# The installed command is lightz-nightly (the stable launcher is renamed by the packager):
# `Exec=lightz %F` would start the stable app from the Nightly menu entry, arguments intact.
grep -qx 'Exec=lightz-nightly %F' "$share/applications/$nightly_id.desktop"
# `! grep` is not a condition: errexit skips it, so a match would pass. Fail the assertion explicitly.
if grep -q '^MimeType=' "$share/applications/$nightly_id.desktop"; then
  echo 'FAIL: the Nightly desktop file still declares MimeType' >&2
  exit 1
fi
test -f "$share/metainfo/$nightly_id.metainfo.xml"
grep -q "<id>$nightly_id</id>" "$share/metainfo/$nightly_id.metainfo.xml"
grep -q "<binary>lightz-nightly</binary>" "$share/metainfo/$nightly_id.metainfo.xml"
test -f "$share/icons/hicolor/256x256/apps/$nightly_id.png"

test ! -e "$stage/bin/.lightz-nightly"
cmp "$stage/bin/lightz" "$bin/.lightz-nightly/lightz"
cmp "$stage/bin/lightz-cli" "$bin/.lightz-nightly/lightz-cli"
export HOME="$work/home with space"
unset XDG_DATA_HOME LIGHTZ_CONFIG_DIR LIGHTZ_LIBRARY
expect() {
  expected="$1"
  shift
  actual="$(PATH="$bin:$PATH" lightz-nightly "$@")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}
# The GUI starts through the Nightly launch profile: one folder decision, made by the launcher.
profile="$HOME/.local/share/lightz-nightly"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<-->\n<photo with spaces.dng>\n<--other-name.dng>\n' "$profile")" \
  'photo with spaces.dng' '--other-name.dng'
export XDG_DATA_HOME="$work/xdg with space"
profile="$XDG_DATA_HOME/lightz-nightly"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<-->\n<sample.dng>\n' "$profile")" sample.dng
# A bare query is answered by the binary as usual, with no profile tokens and no env written.
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--version>\n')" --version
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<-V>\n')" -V
# The Launcher's own form arrives already shaped: its profile root wins and nothing is added.
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n</launcher/profiles/lightz>\n<--version>\n')" \
  --launch-profile nightly-v1 --profile-root /launcher/profiles/lightz --version
# An inherited stable variable is passed through untouched (the nightly build refuses it), never
# silently reinterpreted as the profile.
LIGHTZ_CONFIG_DIR="$work/explicit with space" expect \
  "$(printf 'CONFIG=<%s>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<-->\n<sample.dng>\n' "$work/explicit with space" "$profile")" sample.dng

# The headless CLI takes the same profile through its two host variables.
cli_actual=$(PATH="$bin:$PATH" lightz-nightly-cli calibrate)
cli_expected=$(printf 'CONFIG=<%s>\nLIBRARY=<%s>\n<calibrate>\n' "$profile/Settings" "$profile/Library")
if [[ "$cli_actual" != "$cli_expected" ]]; then
  printf 'expected:\n%s\nactual:\n%s\n' "$cli_expected" "$cli_actual" >&2
  exit 1
fi
cli_actual=$(LIGHTZ_CONFIG_DIR="$work/cli settings" LIGHTZ_LIBRARY="$work/cli library" PATH="$bin:$PATH" lightz-nightly-cli calibrate)
cli_expected=$(printf 'CONFIG=<%s>\nLIBRARY=<%s>\n<calibrate>\n' "$work/cli settings" "$work/cli library")
if [[ "$cli_actual" != "$cli_expected" ]]; then
  printf 'expected:\n%s\nactual:\n%s\n' "$cli_expected" "$cli_actual" >&2
  exit 1
fi

echo "PASS: Arch Nightly handoff isolates the profile and preserves launch arguments"
