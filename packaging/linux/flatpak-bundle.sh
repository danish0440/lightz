#!/usr/bin/env bash
# Repackage a LightZ Linux tarball as a single-file Flatpak bundle:
#
#   $DIST/lightz-<version>-linux-<arch>.flatpak
#
# Usage: packaging/linux/flatpak-bundle.sh [--no-test] [TARBALL]
#
# TARBALL defaults to $DIST/lightz-<version>-linux-<arch>.tar.gz from package.sh. The bundle
# is built for the host architecture (x86_64 or aarch64), which must match the tarball's.
# Needs flatpak, flatpak-builder and the SVG pixbuf loader (librsvg2-common) for the host's
# `appstreamcli compose`; the freedesktop runtime and SDK named in the manifest are
# installed per-user from Flathub. Unless --no-test, the bundle is then installed per-user and
# `lightz-cli --version` is run inside the sandbox as a smoke test.
# Manifest: packaging/linux/flatpak/com.pintaz.lightz.bundle.yml.
set -euo pipefail
# shellcheck source=../env.sh
. "$(dirname "${BASH_SOURCE[0]}")/../env.sh"
HERE="$ROOT/packaging/linux"
APP_ID=com.pintaz.lightz
FLATPAK_ID="$APP_ID"
# The remote indexes both app IDs on the stable ref branch; IDs isolate installations.
FLATPAK_BRANCH=stable
if [[ "${LIGHTZ_BUILD_CHANNEL:-}" == nightly-v1 || "$VERSION" == *-nightly* ]]; then
  FLATPAK_ID="$APP_ID.nightly"
fi
FLATHUB=https://dl.flathub.org/repo/flathub.flatpakrepo

TEST=1
OCI=0
TARBALL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-test) TEST=0; shift ;;
    --oci) OCI=1; shift ;;
    -h | --help) sed -n '2,14p' "$0"; exit 0 ;;
    -*) echo "unknown argument: $1" >&2; exit 2 ;;
    *) TARBALL="$1"; shift ;;
  esac
done

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ;;
  aarch64 | arm64) ARCH=aarch64 ;;
  *) echo "unsupported architecture $ARCH" >&2; exit 2 ;;
esac
BASENAME="lightz-$VERSION-linux-$ARCH"
TARBALL="${TARBALL:-$DIST/$BASENAME.tar.gz}"
[[ -f "$TARBALL" ]] || { echo "error: $TARBALL not found (run packaging/linux/package.sh --formats tar first)" >&2; exit 1; }
for tool in flatpak flatpak-builder; do
  command -v "$tool" >/dev/null || { echo "error: $tool not found (apt install flatpak flatpak-builder librsvg2-common)" >&2; exit 1; }
done

echo "==> LightZ $VERSION Flatpak bundle for $ARCH from $(basename "$TARBALL")"

WORK="$CARGO_TARGET_DIR/flatpak-bundle"
rm -rf "$WORK"
mkdir -p "$WORK/stage"
tar -xzf "$TARBALL" -C "$WORK/stage" --strip-components=1
# Stable ships bin/lightz; a Nightly tar ships its launchers in bin/ and the real binaries in
# lib/lightz-nightly (packaging/linux/package.sh stage_nightly).
[[ -x "$WORK/stage/bin/lightz" || -x "$WORK/stage/lib/lightz-nightly/lightz" ]] \
  || { echo "error: $TARBALL has no LightZ binary" >&2; exit 1; }
if [[ "$FLATPAK_ID" != "$APP_ID" ]]; then
  gui="$WORK/stage/lib/lightz-nightly/lightz"
  cli="$WORK/stage/lib/lightz-nightly/lightz-cli"
  [[ -x "$gui" && -x "$cli" ]] \
    || { echo "error: $TARBALL is not a Nightly tar (no lib/lightz-nightly binaries); pass the -nightly- tarball from package.sh" >&2; exit 1; }
  # The bundle installs the real binaries in /app/libexec and its own wrappers in /app/bin: inside
  # the sandbox the Nightly Flatpak id isolates the data, and the profile keeps it explicit.
  mv "$gui" "$WORK/stage/bin/lightz-bin"
  mv "$cli" "$WORK/stage/bin/lightz-cli-bin"
  rm -rf "$WORK/stage/lib" "$WORK/stage/bin/lightz-nightly" "$WORK/stage/bin/lightz-nightly-cli"
  cat >"$WORK/stage/bin/lightz" <<'WRAPPER'
#!/bin/sh
set -eu
case "${1:-}" in
  --launch-profile | --profile-root | --version | -V | --help | -h) exec /app/libexec/lightz "$@" ;;
esac
profile="${XDG_DATA_HOME:-${HOME:?HOME is required}/.var/app/com.pintaz.lightz.nightly/data}/lightz-nightly"
exec /app/libexec/lightz --launch-profile nightly-v1 --profile-root "$profile" -- "$@"
WRAPPER
  cat >"$WORK/stage/bin/lightz-cli" <<'WRAPPER'
#!/bin/sh
set -eu
case "${1:-}" in
  --version | -V | --help | -h) exec /app/libexec/lightz-cli "$@" ;;
esac
profile="${XDG_DATA_HOME:-${HOME:?HOME is required}/.var/app/com.pintaz.lightz.nightly/data}/lightz-nightly"
if [ -z "${LIGHTZ_CONFIG_DIR+x}" ]; then export LIGHTZ_CONFIG_DIR="$profile/Settings"; fi
if [ -z "${LIGHTZ_LIBRARY+x}" ]; then export LIGHTZ_LIBRARY="$profile/Library"; fi
exec /app/libexec/lightz-cli "$@"
WRAPPER
  chmod 755 "$WORK/stage/bin/lightz" "$WORK/stage/bin/lightz-cli"
  # The tar names the desktop entry, the metainfo, the icon and the doc folder for the *window* id
  # (…nightly-v1). The Flatpak id (…nightly) is the artifact id and owns them inside the sandbox;
  # StartupWMClass stays on the window id the app really sets.
  nightly_id="$APP_ID.nightly-v1"
  sed -e "s#^Exec=lightz-nightly\([[:space:]]\|$\)#Exec=lightz\1#" \
      -e "s|^TryExec=lightz-nightly$|TryExec=lightz|" \
      -e "s|^Icon=.*|Icon=$FLATPAK_ID|" \
      "$WORK/stage/share/applications/$nightly_id.desktop" >"$WORK/stage/share/applications/$FLATPAK_ID.desktop"
  rm -f "$WORK/stage/share/applications/$nightly_id.desktop"
  sed -e "s|<id>$nightly_id</id>|<id>$FLATPAK_ID</id>|g" \
      -e "s|<launchable type=\"desktop-id\">$nightly_id.desktop</launchable>|<launchable type=\"desktop-id\">$FLATPAK_ID.desktop</launchable>|g" \
      -e "s|<icon type=\"stock\">$nightly_id</icon>|<icon type=\"stock\">$FLATPAK_ID</icon>|g" \
      "$WORK/stage/share/metainfo/$nightly_id.metainfo.xml" >"$WORK/stage/share/metainfo/$FLATPAK_ID.metainfo.xml"
  rm -f "$WORK/stage/share/metainfo/$nightly_id.metainfo.xml"
  # Nightly opens no files from the file manager: no MIME database, as in the tar.
  rm -rf "$WORK/stage/share/mime"
  nightly_icon="$WORK/stage/share/icons/hicolor/256x256/apps/$nightly_id.png"
  [[ -f "$nightly_icon" ]] || nightly_icon="$ROOT/assets/app-icon/lightz-nightly.png"
  [[ -f "$nightly_icon" ]] || nightly_icon="$ROOT/assets/app-icon/hicolor/256x256/apps/$APP_ID.png"
  install -Dm644 "$nightly_icon" "$WORK/stage/share/icons/hicolor/256x256/apps/$FLATPAK_ID.png"
  rm -f "$WORK/stage/share/icons/hicolor/256x256/apps/$nightly_id.png"
  if [[ -d "$WORK/stage/share/doc/lightz-nightly" ]]; then
    # The manifest copies share/doc/lightz (the stable name).
    mv "$WORK/stage/share/doc/lightz-nightly" "$WORK/stage/share/doc/lightz"
  fi
  sed -e "s|ai\.storyteller\.lightz|$FLATPAK_ID|g" \
      -e 's|- install -Dm755 bin/lightz /app/bin/lightz|- install -Dm755 bin/lightz-bin /app/libexec/lightz\n      - install -Dm755 bin/lightz /app/bin/lightz|' \
      -e 's|- install -Dm755 bin/lightz-cli /app/bin/lightz-cli|- install -Dm755 bin/lightz-cli-bin /app/libexec/lightz-cli\n      - install -Dm755 bin/lightz-cli /app/bin/lightz-cli|' \
      -e '/# The same MIME definitions the deb\/rpm install\./d' \
      -e '/share\/mime\/packages/d' \
      "$HERE/flatpak/$APP_ID.bundle.yml" >"$WORK/$FLATPAK_ID.yml"
else
  cp "$HERE/flatpak/$APP_ID.bundle.yml" "$WORK/$FLATPAK_ID.yml"
fi

flatpak remote-add --user --if-not-exists flathub "$FLATHUB"
# --disable-rofiles-fuse: no FUSE in containers and CI runners.
flatpak-builder --user --install-deps-from=flathub --disable-rofiles-fuse --force-clean \
  --default-branch="$FLATPAK_BRANCH" --repo="$WORK/repo" --state-dir="$WORK/state" "$WORK/build" "$WORK/$FLATPAK_ID.yml"

OUT="$DIST/$BASENAME.flatpak"
# --runtime-repo lets `flatpak install` fetch the freedesktop runtime from Flathub if missing.
flatpak build-bundle --runtime-repo="$FLATHUB" "$WORK/repo" "$OUT" "$FLATPAK_ID" "$FLATPAK_BRANCH"
echo "wrote $OUT"
if [[ "$OCI" = 1 ]]; then
  OUT_OCI="$DIST/$BASENAME-oci"
  rm -rf "$OUT_OCI"
  flatpak build-bundle --oci "$WORK/repo" "$OUT_OCI" "$FLATPAK_ID" "$FLATPAK_BRANCH"
  echo "wrote OCI layout to $OUT_OCI"
fi

if [[ "$TEST" = 1 ]]; then
  flatpak install --user -y --noninteractive --reinstall "$OUT"
  flatpak info --user "$FLATPAK_ID"
  flatpak run --command=lightz-cli "$FLATPAK_ID" --version
  if [[ "$FLATPAK_ID" = "$APP_ID" ]]; then
    flatpak run --command=sh "$FLATPAK_ID" -c 'ls /app/share/applications /app/share/metainfo /app/share/mime/packages /app/share/icons/hicolor/*/apps'
  else
    # Nightly installs no MIME database; the GUI lives in /app/libexec behind its /app/bin wrapper.
    flatpak run --command=sh "$FLATPAK_ID" -c 'ls /app/share/applications /app/share/metainfo /app/share/icons/hicolor/*/apps /app/libexec'
  fi
fi
echo "==> done"
ls -lh "$OUT"
