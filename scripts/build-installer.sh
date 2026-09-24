#!/usr/bin/env bash
# Builds dist/Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run and dist/SHA256SUMS.txt
#   scripts/build-installer.sh <Cura-5.13.0.tar.gz> <patched CuraEngine> [dist-dir]
# Refuses binaries/resources that contain the builder's user name, home path or host name.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CURA_SRC="$1"; ENGINE="$2"; DIST="$(realpath -m "${3:-$REPO/dist}")"
VERSION="$(sed -n 's/^readonly VERSION="\(.*\)"/\1/p' "$REPO/installer/efnl.sh")"
NAME="Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run"
work="$(mktemp -d)"; trap 'rm -rf -- "$work"' EXIT
python3 "$REPO/scripts/make_payload.py" "$CURA_SRC" "$ENGINE" "$work"
mkdir -p "$work/bundle/installer/lang"
cp "$REPO/installer/efnl.sh" "$work/bundle/installer/"; chmod 755 "$work/bundle/installer/efnl.sh"
cp "$REPO/installer/lang/"*.sh "$work/bundle/installer/lang/"; chmod 644 "$work/bundle/installer/lang/"*.sh
cp -r "$work/payload" "$work/bundle/installer/payload"
# Leak check (user name, home, host name) over everything that is shipped.
pat="$(printf '%s|%s|%s' "$HOME" "/home/$(id -un)" "$(hostname)")"
if grep -raE -- "$pat" "$work/bundle" >/dev/null; then echo "leak check FAILED:" >&2; grep -ralE -- "$pat" "$work/bundle" >&2; exit 1; fi
tar --sort=name --mtime=@315532800 --owner=0 --group=0 --numeric-owner --format=gnu \
    -C "$work/bundle" -cf "$work/bundle.tar" installer
hdr="$(cat "$REPO/installer/run-header.sh")"
lines=$(( $(printf '%s\n' "$hdr" | wc -l) + 1 ))
mkdir -p "$DIST"
{ printf '%s\n' "$hdr" | sed -e "s/@VERSION@/$VERSION/" -e "s/@ARCHIVE_SHA256@/$(sha256sum "$work/bundle.tar" | cut -d' ' -f1)/" -e "s/@ARCHIVE_LINE@/$lines/"
  cat "$work/bundle.tar"; } > "$DIST/$NAME"
chmod 755 "$DIST/$NAME"
( cd "$DIST" && sha256sum "$NAME" > SHA256SUMS.txt && cat SHA256SUMS.txt )
cp "$work/payload/SHA256SUMS" "$DIST/payload-SHA256SUMS.txt"
