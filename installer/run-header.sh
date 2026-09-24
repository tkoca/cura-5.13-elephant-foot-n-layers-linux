#!/usr/bin/env bash
# Cura 5.13 - Elephant Foot N Layers @VERSION@ for Linux x86_64 - self-extracting installer.
#   ./Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run install [APPIMAGE] | uninstall | status  [--system] [--gui] [--yes|--silent]
# The embedded archive (after the __ARCHIVE__ line) is checked against the SHA-256 below before use.
set -euo pipefail
ARCHIVE_SHA256="@ARCHIVE_SHA256@"
ARCHIVE_LINE=@ARCHIVE_LINE@
self="$(readlink -f -- "$0")"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/cura-efnl.XXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
tail -n +"$ARCHIVE_LINE" -- "$self" > "$tmp/bundle.tar"
if [ "$(sha256sum -- "$tmp/bundle.tar" | cut -d' ' -f1)" != "$ARCHIVE_SHA256" ]; then
  echo "ERROR: this installer file is damaged (checksum mismatch). Download it again." >&2; exit 1
fi
tar -xf "$tmp/bundle.tar" -C "$tmp" --no-same-owner
rm -f -- "$tmp/bundle.tar"
set +e
EFNL_PROG="$(basename -- "$0")" bash "$tmp/installer/efnl.sh" "$@"
rc=$?
exit $rc
# shellcheck disable=SC2317
__ARCHIVE__
