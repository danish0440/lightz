#!/usr/bin/env bash
# Stage the LightZ Nightly-only handoff for the Arch packager.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
source_tree="$1"
work="$2"
destination="$3"
basename="$4"
stage="$work/$basename"

mkdir -p "$work"
cp -R "$source_tree" "$stage"
mkdir "$stage/bin/.lightz-nightly"
mv "$stage/bin/lightz" "$stage/bin/.lightz-nightly/lightz"
mv "$stage/bin/lightz-cli" "$stage/bin/.lightz-nightly/lightz-cli"
cp "$here/nightly-arch-launch.sh" "$stage/bin/lightz"
cp "$here/nightly-arch-launch.sh" "$stage/bin/lightz-cli"
chmod 755 "$stage/bin/lightz" "$stage/bin/lightz-cli"

# The packager installs this tree as it is, so the Nightly desktop entry, metainfo and icon are
# named for the Nightly channel here: leaving the stable ids would make them rename three files
# and would collide with a stable install's menu entry.
app_id=com.pintaz.lightz
nightly_id="$app_id.nightly-v1"
if [ -f "$stage/share/applications/$app_id.desktop" ]; then
  # The packager renames the launchers to lightz-nightly(-cli) when it installs this tree, so the
  # menu entry must name the installed command: `Exec=lightz` would start stable beside it.
  sed -e 's#^Exec=lightz\([[:space:]]\|$\)#Exec=lightz-nightly\1#' \
      -e 's#^TryExec=lightz$#TryExec=lightz-nightly#' \
      -e "s|^Icon=$app_id$|Icon=$nightly_id|" \
      -e "s|^StartupWMClass=.*|StartupWMClass=$nightly_id|" \
      -e "s|^Name=LightZ$|Name=LightZ Nightly|" \
      -e '/^MimeType=/d' \
      "$stage/share/applications/$app_id.desktop" >"$stage/share/applications/$nightly_id.desktop"
  rm -f "$stage/share/applications/$app_id.desktop"
fi
if [ -f "$stage/share/metainfo/$app_id.metainfo.xml" ]; then
  sed -e "s|<id>$app_id</id>|<id>$nightly_id</id>|g" \
      -e "s|<name>LightZ</name>|<name>LightZ Nightly</name>|g" \
      -e "s|<launchable type=\"desktop-id\">$app_id.desktop</launchable>|<launchable type=\"desktop-id\">$nightly_id.desktop</launchable>|g" \
      -e "s|<icon type=\"stock\">$app_id</icon>|<icon type=\"stock\">$nightly_id</icon>|g" \
      -e "s|<binary>lightz</binary>|<binary>lightz-nightly</binary>|g" \
      "$stage/share/metainfo/$app_id.metainfo.xml" >"$stage/share/metainfo/$nightly_id.metainfo.xml"
  rm -f "$stage/share/metainfo/$app_id.metainfo.xml"
fi
if [ -d "$stage/share/icons/hicolor" ]; then
  nightly_icon="$here/../../assets/app-icon/lightz-nightly.png"
  if [ -f "$nightly_icon" ]; then
    rm -rf "$stage/share/icons/hicolor"
    install -Dm644 "$nightly_icon" "$stage/share/icons/hicolor/256x256/apps/$nightly_id.png"
  fi
fi
tar -C "$work" -czf "$destination/$basename.tar.gz" "$basename"
echo "wrote $destination/$basename.tar.gz"
