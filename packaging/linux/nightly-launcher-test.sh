#!/usr/bin/env bash
# Validate the Nightly launchers without building or opening LightZ: the unpacked tar's
# `lightz` (GUI in `lightz-bin`) and the deb/rpm/FHS `lightz-nightly` (GUI in
# lib/lightz-nightly). A recorder stands in for both binaries and prints its argv and env.
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

# ---- the unpacked tar: lightz (launcher) + lightz-bin (the GUI) --------------------------
tar_dir="$work/tar"
mkdir -p "$tar_dir"
cp "$work/recorder" "$tar_dir/lightz-bin"
install -m755 "$HERE/nightly-tar-launch.sh" "$tar_dir/lightz"
profile="$HOME/.local/share/lightz-nightly"

# A hand-unpacked tar opens its own Nightly profile, whatever the working directory is.
cd "$work"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<-->\n<photo with spaces.dng>\n<--other-name.dng>\n' "$profile")" \
  "$("$tar_dir/lightz" 'photo with spaces.dng' '--other-name.dng')"
export XDG_DATA_HOME="$work/xdg with space"
profile="$XDG_DATA_HOME/lightz-nightly"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<-->\n<sample.dng>\n' "$profile")" \
  "$("$tar_dir/lightz" sample.dng)"
unset XDG_DATA_HOME
profile="$HOME/.local/share/lightz-nightly"

# The Launcher's own form arrives already shaped: its profile root wins and nothing is added.
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n</launcher/profiles/lightz>\n<--version>\n')" \
  "$("$tar_dir/lightz" --launch-profile nightly-v1 --profile-root /launcher/profiles/lightz --version)"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--profile-root>\n<%s>\n<-->\n<photo.dng>\n' "$work/explicit root")" \
  "$("$tar_dir/lightz" --profile-root "$work/explicit root" -- photo.dng)"
# The version query is answered by the binary itself, with no profile tokens.
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--version>\n')" "$("$tar_dir/lightz" --version)"

# ---- the deb/rpm and the unpacked FHS tar: bin/lightz-nightly + lib/lightz-nightly -------
fhs="$work/fhs"
mkdir -p "$fhs/bin" "$fhs/lib/lightz-nightly"
cp "$work/recorder" "$fhs/lib/lightz-nightly/lightz"
cp "$work/recorder" "$fhs/lib/lightz-nightly/lightz-cli"
install -m755 "$HERE/nightly-fhs-launch.sh" "$fhs/bin/lightz-nightly"
install -m755 "$HERE/nightly-fhs-cli-launch.sh" "$fhs/bin/lightz-nightly-cli"

# The real binary is resolved beside the launcher, so an unpacked tree works anywhere.
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<-->\n<photo with spaces.dng>\n' "$profile")" \
  "$("$fhs/bin/lightz-nightly" 'photo with spaces.dng')"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n</launcher/profiles/lightz>\n<--version>\n')" \
  "$("$fhs/bin/lightz-nightly" --launch-profile nightly-v1 --profile-root /launcher/profiles/lightz --version)"
expect "$(printf 'CONFIG=<<unset>>\nLIBRARY=<<unset>>\n<--version>\n')" "$("$fhs/bin/lightz-nightly" --version)"

# The headless CLI takes the same profile through its two host variables; explicit values win.
expect "$(printf 'CONFIG=<%s>\nLIBRARY=<%s>\n<calibrate>\n' "$profile/Settings" "$profile/Library")" \
  "$("$fhs/bin/lightz-nightly-cli" calibrate)"
expect "$(printf 'CONFIG=<%s>\nLIBRARY=<%s>\n<calibrate>\n' "$work/cli settings" "$work/cli library")" \
  "$(LIGHTZ_CONFIG_DIR="$work/cli settings" LIGHTZ_LIBRARY="$work/cli library" "$fhs/bin/lightz-nightly-cli" calibrate)"

# Neither launcher writes anything by itself (no folder, no file).
test ! -e "$profile"
test ! -e "$HOME/Pictures"

echo "PASS: the Nightly tar and FHS launchers isolate the profile and pass the Launcher protocol through"
