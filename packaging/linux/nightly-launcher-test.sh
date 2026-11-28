#!/usr/bin/env bash
# Validate the Nightly launchers without building or opening LightZ: the unpacked tar's
# `lightz` (craft-common-actions' rendered template, GUI in `lightz-bin`) and the
# deb/rpm/FHS `lightz-nightly` (GUI in lib/lightz-nightly). A recorder stands in for both
# binaries and prints its argv and env.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat >"$work/recorder" <<'RECORDER'
#!/bin/sh
printf 'CONFIG=<%s>\n' "${LIGHTZ_CONFIG_DIR-<unset>}"
printf 'LIBRARY=<%s>\n' "${LIGHTZ_LIBRARY-<unset>}"
for arg in "$@"; do
  printf '<%s>\n' "$arg"
done
RECORDER
chmod 755 "$work/recorder"

expect() {
  local expected="$1" actual="$2"
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

unset XDG_DATA_HOME LIGHTZ_CONFIG_DIR LIGHTZ_LIBRARY
export HOME="$work/home with space"

# ---- the unpacked tar: the shared template as lightz (GUI in lightz-bin) ----------------
tar_dir="$work/tar"
mkdir -p "$tar_dir"
cp "$work/recorder" "$tar_dir/lightz-bin"
install -m755 "$HERE/nightly-tar-launch.sh" "$tar_dir/lightz"
identity="com.pintaz.lightz.nightly"
profile="$HOME/.local/share/$identity"

# The shared template, rendered for LightZ: a hand-unpacked tar opens the channel's own profile
# whatever the working directory is, and every argument follows the profile tokens.
cd "$work"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<-->\n<photo with spaces.dng>\n<--other-name.dng>\n' "$profile")" \
  "$("$tar_dir/lightz" 'photo with spaces.dng' '--other-name.dng')"
export XDG_DATA_HOME="$work/xdg with space"
profile="$XDG_DATA_HOME/$identity"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<-->\n<sample.dng>\n' "$profile")" \
  "$("$tar_dir/lightz" sample.dng)"
unset XDG_DATA_HOME
profile="$HOME/.local/share/$identity"

# A version query is asked in the Launcher's own form, so the binary answers before any profile.
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<--version>\n' "$profile")" \
  "$("$tar_dir/lightz" --version)"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<--version>\n' "$profile")" \
  "$("$tar_dir/lightz" -V)"

# The AppZ names its own profile and per-install root: the pair goes to the GUI unchanged.
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<-->\n<photo.dng>\n' "$work/launcher profile with space")" \
  "$("$tar_dir/lightz" --launch-profile nightly-v1 --profile-root "$work/launcher profile with space" -- photo.dng)"

# The bytes are the shared template rendered for this app, not a local script.
expected="dbb1dff470eaff5ecfe1cf03cc43459d4d8796a0e8875fc0bea9563e30deba59"
actual="$(sha256sum "$HERE/nightly-tar-launch.sh" | cut -d' ' -f1)"
[[ "$actual" == "$expected" ]] || { printf 'nightly-tar-launch.sh is %s, not the rendered template %s\n' "$actual" "$expected" >&2; exit 1; }

# ---- the deb/rpm and the unpacked FHS tar: bin/lightz-nightly + lib/lightz-nightly -------
fhs="$work/fhs"
mkdir -p "$fhs/bin" "$fhs/lib/lightz-nightly"
cp "$work/recorder" "$fhs/lib/lightz-nightly/lightz"
cp "$work/recorder" "$fhs/lib/lightz-nightly/lightz-cli"
install -m755 "$HERE/nightly-fhs-launch.sh" "$fhs/bin/lightz-nightly"
install -m755 "$HERE/nightly-fhs-cli-launch.sh" "$fhs/bin/lightz-nightly-cli"
# The distro formats keep their own profile folder, so they are not the tar's identity.
fhs_profile="$HOME/.local/share/lightz-nightly"

# The real binary is resolved beside the launcher, so an unpacked tree works anywhere.
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<-->\n<photo with spaces.dng>\n' "$fhs_profile")" \
  "$("$fhs/bin/lightz-nightly" 'photo with spaces.dng')"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n</launcher/profiles/lightz>\n<--version>\n')" \
  "$("$fhs/bin/lightz-nightly" --launch-profile nightly-v1 --profile-root /launcher/profiles/lightz --version)"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--version>\n')" "$("$fhs/bin/lightz-nightly" --version)"

# The headless CLI takes the same profile through its two host variables; explicit values win.
expect "$(printf 'CONFIG=<%s>\nLIBRARY=<%s>\n<calibrate>\n' "$fhs_profile/Settings" "$fhs_profile/Library")" \
  "$("$fhs/bin/lightz-nightly-cli" calibrate)"
expect "$(printf 'CONFIG=<%s>\nLIBRARY=<%s>\n<calibrate>\n' "$work/cli settings" "$work/cli library")" \
  "$(LIGHTZ_CONFIG_DIR="$work/cli settings" LIGHTZ_LIBRARY="$work/cli library" "$fhs/bin/lightz-nightly-cli" calibrate)"

# Neither launcher writes anything by itself (no folder, no file).
test ! -e "$profile"
test ! -e "$fhs_profile"
test ! -e "$HOME/Pictures"

echo "PASS: the Nightly tar launcher is the shared template and the FHS launchers isolate the profile"
