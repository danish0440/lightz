#!/bin/sh
# The headless Nightly CLI (`usr/bin/lightz-nightly-cli`). It is not the GUI's Launcher
# protocol: the same profile reaches it through its two documented host variables, and an explicit
# value still wins.
set -eu
self="$(readlink -f "$0")"
here="$(dirname "$self")"
# Never fall back to a relative path: an unresolvable $0 is a broken install, not a guess.
[ -n "$self" ] && [ "${here#/}" != "$here" ] || { echo "error: cannot resolve $0" >&2; exit 2; }
real="$here/../lib/lightz-nightly/lightz-cli"
case "${1:-}" in
  --version | -V | --help | -h) exec "$real" "$@" ;;
esac
profile="${XDG_DATA_HOME:-${HOME:?HOME is required}/.local/share}/lightz-nightly"
if [ -z "${LIGHTZ_CONFIG_DIR+x}" ]; then export LIGHTZ_CONFIG_DIR="$profile/Settings"; fi
if [ -z "${LIGHTZ_LIBRARY+x}" ]; then export LIGHTZ_LIBRARY="$profile/Library"; fi
exec "$real" "$@"
