#!/usr/bin/env bash
# Builds CuraEngine 5.13.0 for Linux x86_64 inside the efnl-build container.
#
#   scripts/build-curaengine.sh [--unpatched] <CuraEngine-5.13.0.tar.gz> <out-dir>
#
# 1. Extracts the upstream CuraEngine 5.13.0 tag archive into /opt/efnl/work (inside the container).
# 2. Verifies the pristine src/slicer.cpp (SHA-256, LF).
# 3. Applies patches/CuraEngine-5.13.0.patch (skipped with --unpatched: control build).
# 4. conan build with the UltiMaker Conan configuration, default CuraEngine options
#    (Arcus + plugins on, Sentry off), Release.
# 5. Links without RPATH (the AppImage provides the libraries through LD_LIBRARY_PATH), strips the
#    binary, sets the same relative program interpreter as the official engine and checks:
#    GLIBC <= 2.35, GLIBCXX <= 3.4.32, no RPATH, no build-host paths.
#
# The Conan home and work folder are neutral paths (/opt/efnl/...) so no user or machine name
# can end up in the binary (dependency __FILE__ strings).
set -euo pipefail

UNPATCHED=0
if [[ "${1:-}" == "--unpatched" ]]; then UNPATCHED=1; shift; fi
[[ $# -eq 2 ]] || { echo "usage: $0 [--unpatched] <CuraEngine-5.13.0.tar.gz> <out-dir>" >&2; exit 2; }

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC_TGZ="$(realpath "$1")"
OUT="$(realpath -m "$2")"
IMAGE="${EFNL_IMAGE:-efnl-build:5.13}"
CONAN_VOLUME="${EFNL_CONAN_VOLUME:-efnl-conan}"
CONAN_CONFIG_REF="${EFNL_CONAN_CONFIG_REF:-bba7984a7363709f239fc13a3a3e0b02ecc2488b}"
JOBS="${EFNL_JOBS:-$(nproc)}"
mkdir -p "$OUT"

podman run --rm \
  -v "$REPO:/opt/efnl/repo:ro,Z" \
  -v "$SRC_TGZ:/opt/efnl/src.tar.gz:ro,Z" \
  -v "$OUT:/opt/efnl/out:Z" \
  -v "$CONAN_VOLUME:/opt/efnl/conan" \
  -e UNPATCHED="$UNPATCHED" -e CONAN_CONFIG_REF="$CONAN_CONFIG_REF" -e JOBS="$JOBS" \
  "$IMAGE" bash -euo pipefail -c '
PRISTINE=0397cf03e606bd7f2f3653ee7fce28d0ad73b28c146e66aa78f3e7c49e89e5ef
export CONAN_HOME=/opt/efnl/conan TMPDIR=/opt/efnl/conan/tmp
mkdir -p "$TMPDIR"
if [[ ! -f "$CONAN_HOME/.efnl-config-$CONAN_CONFIG_REF" ]]; then
  git clone -q https://github.com/Ultimaker/conan-config.git /opt/efnl/cc
  git -C /opt/efnl/cc checkout -q "$CONAN_CONFIG_REF"
  conan config install /opt/efnl/cc
  conan profile detect --force >/dev/null
  touch "$CONAN_HOME/.efnl-config-$CONAN_CONFIG_REF"
fi
rm -rf /opt/efnl/work && mkdir -p /opt/efnl/work && cd /opt/efnl/work
tar -xzf /opt/efnl/src.tar.gz
cd CuraEngine-5.13.0
actual=$(tr -d "\r" < src/slicer.cpp | sha256sum | cut -d" " -f1)
[[ "$actual" == "$PRISTINE" ]] || { echo "Unexpected upstream slicer.cpp ($actual). Is this CuraEngine 5.13.0?" >&2; exit 1; }
if [[ "$UNPATCHED" == 0 ]]; then
  python3 /opt/efnl/repo/scripts/apply_patch.py /opt/efnl/repo/patches/CuraEngine-5.13.0.patch .
fi
conan build . --build=missing -s build_type=Release -c tools.build:jobs=$JOBS \
  -c "tools.build:cflags=[\"-ffile-prefix-map=/opt/efnl=.\"]" \
  -c "tools.build:cxxflags=[\"-ffile-prefix-map=/opt/efnl=.\"]" \
  -c "tools.cmake.cmaketoolchain:extra_variables={\"CMAKE_SKIP_BUILD_RPATH\": \"ON\", \"CMAKE_SKIP_INSTALL_RPATH\": \"ON\", \"CMAKE_SKIP_RPATH\": \"ON\"}"
bin=$(find . -type f -name CuraEngine -perm -u+x | head -1)
[[ -n "$bin" ]] || { echo "CuraEngine not produced" >&2; exit 1; }
name=CuraEngine; [[ "$UNPATCHED" == 1 ]] && name=CuraEngine.unpatched
cp "$bin" /opt/efnl/out/$name
strip --strip-all /opt/efnl/out/$name
# Same program interpreter as the official AppImage engine: relative, resolved by AppRun
# (runtime/compat or runtime/default) so that the bundled or the system glibc is used consistently.
patchelf --set-interpreter lib64/ld-linux-x86-64.so.2 /opt/efnl/out/$name
'
"$REPO/scripts/check-engine.sh" "$OUT/$([[ $UNPATCHED == 1 ]] && echo CuraEngine.unpatched || echo CuraEngine)"
