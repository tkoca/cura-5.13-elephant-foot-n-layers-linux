#!/usr/bin/env bash
# Slicing tests: compares the patched CuraEngine with the official Cura 5.13.0 CuraEngine (Linux).
#
#   tests/engine/slice-tests.sh <extracted AppImage dir (squashfs-root)> <patched CuraEngine>
#                               <patched fdmprinter.def.json (payload)> [unpatched control CuraEngine]
#
# Both engines run inside the AppImage runtime (bundled glibc and libraries), exactly as Cura starts
# them: working directory runtime/compat, LD_LIBRARY_PATH from AppRun.env.
#   S1/S2  layer count 1 -> G-code identical to the official engine
#   S3/S4  N=4 without / with taper: per-layer outer wall inset
#   S5     taper toward a non-zero Horizontal Expansion (+0.1)
#   S6     the maintainer's profile values: -0.4 mm, N=5, taper (-0.40/-0.32/-0.24/-0.16/-0.08/0)
#   S7     (optional) our unpatched control build == official engine (isolates build environment from patch)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APPDIR="$(readlink -f "$1")"; PATCHED="$(readlink -f "$2")"; PRINTER="$(readlink -f "$3")"; CONTROL="${4:+$(readlink -f "$4")}"
WORK="${EFNL_SLICE_WORK:-$(mktemp -d "${TMPDIR:-/tmp}/efnl-slice.XXXXXX")}"
mkdir -p "$WORK"
DEFS="$WORK/definitions"
python3 "$HERE/prepare_definitions.py" "$PRINTER" "$APPDIR/share/cura/resources/definitions/fdmextruder.def.json" "$DEFS"
export CURA_ENGINE_SEARCH_PATH="$DEFS"
MODEL="$HERE/box20.stl"
PASS=0; FAIL=0
check() { if [[ "$2" == 1 ]]; then PASS=$((PASS+1)); echo "  PASS  $1"; else FAIL=$((FAIL+1)); echo "  FAIL  $1"; fi; }

# Stage an engine inside a copy-free AppDir view: the engine must sit in the AppDir root because its
# program interpreter is the relative path lib64/ld-linux-x86-64.so.2 (resolved from runtime/compat).
C="$APPDIR/runtime/compat"
LDP="$APPDIR:$C:$C/lib/x86_64-linux-gnu:$C/usr/lib/x86_64-linux-gnu:$APPDIR/usr/lib/x86_64-linux-gnu:$APPDIR/lib/x86_64-linux-gnu:$APPDIR/usr/lib"
engine_run() {  # engine_run <engine> <args...>
  local engine="$1"; shift
  ( cd "$C" && env -i PATH=/usr/bin:/bin HOME="$WORK" CURA_ENGINE_SEARCH_PATH="$DEFS" LD_LIBRARY_PATH="$LDP" "$engine" "$@" )
}

slice() {  # slice <engine> <name> [settings...]
  local engine="$1" name="$2"; shift 2
  local common=(machine_width=220 machine_depth=220 machine_height=250 machine_center_is_zero=false
    layer_height=0.2 layer_height_0=0.2 adhesion_type=none support_enable=false
    roofing_layer_count=0 flooring_layer_count=0 flooring_extruder_nr=0 roofing_extruder_nr=0 "$@")
  local sets=() s
  for s in "${common[@]}"; do sets+=(-s "$s"); done
  local out="$WORK/$name.gcode"
  if ! engine_run "$engine" slice -j "$DEFS/fdmprinter.def.json" "${sets[@]}" \
        -e0 -j "$DEFS/fdmextruder.def.json" "${sets[@]}" \
        -l "$MODEL" -s mesh_position_x=100 -s mesh_position_y=100 "${sets[@]}" -o "$out" > "$WORK/$name.log" 2>&1 || [[ ! -s "$out" ]]; then
    echo "slice failed: $name (see $WORK/$name.log)" >&2; exit 1
  fi
  printf '%s' "$out"
}
body() { grep -vE '^;(Generated with|TIME|Filament used|PRINT.TIME)' "$1"; }
same() { if cmp -s <(body "$1") <(body "$2"); then echo 1; else echo 0; fi; }
widths() { python3 "$HERE/analyze_gcode.py" "$1" 8 | awk '{print $2}'; }   # X width per layer 0..7
near() { awk -v a="$1" -v b="$2" -v t="${3:-0.02}" 'BEGIN { d = a - b; if (d < 0) d = -d; print (d < t) ? 1 : 0 }'; }
sub() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.3f", a - b }'; }

OFFICIAL="$APPDIR/CuraEngine"
STAGED="$APPDIR/.efnl-test-engine-$$"   # engines must live in the AppDir root (relative interpreter)
cleanup() { rm -f "$STAGED".*; }
trap cleanup EXIT
cp "$PATCHED" "$STAGED.patched"; PATCHED="$STAGED.patched"
[[ -n "$CONTROL" ]] && { cp "$CONTROL" "$STAGED.control"; CONTROL="$STAGED.control"; }

echo "S0 engines start"
for e in "$OFFICIAL" "$PATCHED"; do
  v="$(engine_run "$e" help 2>&1 | grep -m1 'version' || true)"
  check "$(basename "$e"): ${v:-no output}" "$([[ "$v" == *"version 5.13.0"* ]] && echo 1 || echo 0)"
done

echo "S1 layer count 1 == official engine (defaults)"
a="$(slice "$OFFICIAL" official-default)"; b="$(slice "$PATCHED" patched-default)"
check "identical G-code" "$(same "$a" "$b")"

echo "S2 layer count 1 == official engine (initial layer expansion -0.2)"
a="$(slice "$OFFICIAL" official-xy0 xy_offset_layer_0=-0.2)"
b="$(slice "$PATCHED" patched-xy0 xy_offset_layer_0=-0.2 elephant_foot_compensation_layers=1 elephant_foot_compensation_taper=true)"
check "identical G-code" "$(same "$a" "$b")"
mapfile -t base < <(widths "$b"); ref="${base[5]}"

echo "S3 N=4 without taper"
mapfile -t w < <(widths "$(slice "$PATCHED" n4 xy_offset_layer_0=-0.2 elephant_foot_compensation_layers=4 elephant_foot_compensation_taper=false)")
for l in 0 1 2 3; do check "layer $l: width ${w[$l]} = ref-0.4 (inset $(sub "$ref" "${w[$l]}"))" "$(near "$(sub "$ref" "${w[$l]}")" 0.4)"; done
check "layer 4: width ${w[4]} = ref $ref" "$(near "${w[4]}" "$ref")"

echo "S4 N=4 with taper (-0.20, -0.15, -0.10, -0.05, then 0)"
mapfile -t w < <(widths "$(slice "$PATCHED" n4t xy_offset_layer_0=-0.2 elephant_foot_compensation_layers=4 elephant_foot_compensation_taper=true)")
exp=(0.4 0.3 0.2 0.1 0.0)
for l in 0 1 2 3 4; do check "layer $l: inset $(sub "$ref" "${w[$l]}") ~ ${exp[$l]}" "$(near "$(sub "$ref" "${w[$l]}")" "${exp[$l]}")"; done

echo "S5 taper toward a non-zero Horizontal Expansion (+0.1)"
mapfile -t w0 < <(widths "$(slice "$PATCHED" xy01 xy_offset=0.1)"); r="${w0[5]}"
mapfile -t w < <(widths "$(slice "$PATCHED" n2t xy_offset=0.1 xy_offset_layer_0=-0.1 elephant_foot_compensation_layers=2 elephant_foot_compensation_taper=true)")
exp=(0.4 0.2 0.0)
for l in 0 1 2; do check "layer $l: inset $(sub "$r" "${w[$l]}") ~ ${exp[$l]}" "$(near "$(sub "$r" "${w[$l]}")" "${exp[$l]}")"; done

echo "S6 maintainer profile: -0.4 mm, N=5, taper (per side -0.40/-0.32/-0.24/-0.16/-0.08/0)"
mapfile -t w < <(widths "$(slice "$PATCHED" profile xy_offset_layer_0=-0.4 elephant_foot_compensation_layers=5 elephant_foot_compensation_taper=true wall_line_count=4)")
mapfile -t w0 < <(widths "$(slice "$PATCHED" profile-ref wall_line_count=4)"); r="${w0[6]}"
exp=(0.80 0.64 0.48 0.32 0.16 0.00 0.00)
for l in 0 1 2 3 4 5 6; do check "layer $l: inset $(sub "$r" "${w[$l]}") ~ ${exp[$l]} (both sides)" "$(near "$(sub "$r" "${w[$l]}")" "${exp[$l]}")"; done

if [[ -n "$CONTROL" ]]; then
  echo "S7 unpatched control build == official engine (build environment check)"
  a="$(slice "$OFFICIAL" official-default)"; b="$(slice "$CONTROL" control-default)"
  check "identical G-code (defaults)" "$(same "$a" "$b")"
  a="$(slice "$OFFICIAL" official-xy0 xy_offset_layer_0=-0.2)"; b="$(slice "$CONTROL" control-xy0 xy_offset_layer_0=-0.2)"
  check "identical G-code (xy_offset_layer_0=-0.2)" "$(same "$a" "$b")"
fi

echo; echo "RESULT: $PASS passed, $FAIL failed   (G-code: $WORK)"
[[ $FAIL == 0 ]]
