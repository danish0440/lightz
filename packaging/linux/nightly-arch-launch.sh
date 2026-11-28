#!/bin/sh
set -eu

# The Arch packager copies this file over bin/lightz (and bin/lightz-cli) and moves the
# real binaries into bin/.lightz-nightly/. Neither writes outside the Nightly profile.
self="$(readlink -f "$0")"
here="$(dirname "$self")"
# Never fall back to a relative path: an unresolvable $0 is a broken install, not a guess.
[ -n "$self" ] && [ "${here#/}" != "$here" ] || { echo "error: cannot resolve $0" >&2; exit 2; }
profile="${XDG_DATA_HOME:-${HOME:?HOME is required}/.local/share}/lightz-nightly"
case "$(basename "$0")" in
  *-cli)
    real_bin="$here/.lightz-nightly/lightz-cli"
    case "${1:-}" in
      --version | -V | --help | -h) exec "$real_bin" "$@" ;;
    esac
    # The headless CLI has no Launcher protocol: the same profile through its two host variables.
    if [ -z "${LIGHTZ_CONFIG_DIR+x}" ]; then export LIGHTZ_CONFIG_DIR="$profile/Settings"; fi
    if [ -z "${LIGHTZ_LIBRARY+x}" ]; then export LIGHTZ_LIBRARY="$profile/Library"; fi
    exec "$real_bin" "$@"
    ;;
esac
real_bin="$here/.lightz-nightly/lightz"
case "${1:-}" in
  # The Launcher's own profile form is passed on untouched (its root wins over this default), and
  # the queries are answered without any profile.
  --launch-profile | --profile-root | --version | -V | --help | -h) exec "$real_bin" "$@" ;;
esac
exec "$real_bin" --launch-profile nightly-v1 --profile-root "$profile" -- "$@"
