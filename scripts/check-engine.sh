#!/usr/bin/env bash
# Checks a Linux CuraEngine binary against the limits of the official Cura 5.13.0 AppImage:
# GLIBC <= 2.35, GLIBCXX <= 3.4.32, relative interpreter lib64/ld-linux-x86-64.so.2,
# no RPATH/RUNPATH, no build-host paths or user names.
set -euo pipefail
bin="$1"; fail=0
maxv() { objdump -T "$bin" | grep -o "$1[0-9.]*" | sed "s/^$1//" | sort -uV | tail -1; }
g=$(maxv GLIBC_); x=$(maxv GLIBCXX_)
printf 'GLIBC max:   %s (limit 2.35)\nGLIBCXX max: %s (limit 3.4.32)\n' "$g" "$x"
[[ "$(printf '%s\n2.35\n' "$g" | sort -V | tail -1)" == 2.35 ]] || { echo "FAIL: GLIBC too new"; fail=1; }
[[ "$(printf '%s\n3.4.32\n' "$x" | sort -V | tail -1)" == 3.4.32 ]] || { echo "FAIL: GLIBCXX too new"; fail=1; }
interp="$(readelf -l "$bin" | sed -n 's/.*program interpreter: \(.*\)]/\1/p')"
echo "interpreter: $interp"
[[ "$interp" == lib64/ld-linux-x86-64.so.2 ]] || { echo "FAIL: interpreter must be lib64/ld-linux-x86-64.so.2 (as in the AppImage)"; fail=1; }
if readelf -d "$bin" | grep -qE 'RPATH|RUNPATH'; then echo "FAIL: RPATH/RUNPATH present"; fail=1; fi
pat='/home/|/root/|/opt/efnl|\.conan2|'"${USER:-hermes}"'|'"$(hostname)"
n=$(strings -n 6 "$bin" | grep -cE "$pat" || true)
echo "host path/user strings: $n"
[[ "$n" == 0 ]] || { strings -n 6 "$bin" | grep -E "$pat" | head -5 || true; echo "FAIL: leak"; fail=1; }
echo "NEEDED: $(readelf -d "$bin" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' | tr '\n' ' ')"
sha256sum "$bin"
if [[ $fail == 0 ]]; then echo "CHECK PASS"; else echo "CHECK FAIL"; exit 1; fi
