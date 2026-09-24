#!/usr/bin/env bash
# Cura 5.13 - Elephant Foot N Layers: Linux installer / uninstaller.
#
#   efnl.sh install [APPIMAGE] | uninstall | status   [--system] [--gui] [--yes|--silent]
#
# Model: the official UltiMaker Cura 5.13.0 AppImage (read-only squashfs) is verified by SHA-256,
# extracted into a staging folder, its five files are checked against the known Cura 5.13.0 hashes,
# backed up and replaced by the payload, and the staging folder is moved into place atomically.
# The user's AppImage is never modified.
#
# Install locations
#   user   : ~/.local/opt/cura-5.13-efnl, ~/.local/bin/cura-efnl,
#            ${XDG_DATA_HOME:-~/.local/share}/applications/cura-5.13-efnl.desktop
#   system : /opt/cura-5.13-efnl, /usr/local/bin/cura-efnl, /usr/local/share/applications/...
#            (only this part runs as root; profile cleanup always runs as the calling user)
#
# The patched copy gets its own definition cache (XDG_CACHE_HOME=~/.cache/cura-5.13-efnl) so that
# it and the unmodified AppImage never load each other's cached fdmprinter definition (Cura picks
# the cache by modification time and both use ~/.cache/cura/5.13 otherwise).
#
# Exit codes: 0 done (warnings on stderr as "WARNING: ..."), 1 not done / incomplete, 2 usage.
set -euo pipefail
umask 022
if [[ -z "${BASH_VERSINFO[0]:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then echo "bash >= 4 required" >&2; exit 1; fi

readonly VERSION="5.0.0"
readonly ID="cura-5.13-efnl"
readonly APPIMAGE_SHA="100f068127b2598167f00ba4db0e0699ded45adf97bbab2d22ff171a1e1ecc40"
readonly FILES=(
  "CuraEngine"
  "share/cura/resources/definitions/fdmprinter.def.json"
  "share/cura/resources/i18n/tr_TR/fdmprinter.def.json.po"
  "share/cura/resources/i18n/tr_TR/LC_MESSAGES/fdmprinter.def.json.mo"
  "share/cura/resources/setting_visibility/expert.cfg"
)
readonly ORIGINAL_HASHES=(
  "949df48874258ff342b5369853515a93d52fa79448aab050d28ceffe16537f4b"
  "8fbbf8b779e806bd8d0b0e2b8b9be17bdd26a575b7ea1875c20481eb2c7e11ee"
  "ace33455f77ad50ed5d10dbd2f1c2b5732d2c59dcc5e99a9e715ad1bd3f51a85"
  "16dda401341e0805149bdcd674677bf5081413163c6b059255c637187599d3ad"
  "9b646941fa24799eda46ce207f586ab72687d7b02f837264287bb022b720a4ba"
)
readonly KEY_LAYERS="elephant_foot_compensation_layers"
readonly KEY_TAPER="elephant_foot_compensation_taper"
readonly MARK="# ${ID} (managed file, do not edit)"
NEED_MB=1300   # extracted AppImage ~1022 MB + backup + margin

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="${EFNL_PAYLOAD_DIR:-$HERE/payload}"   # payload/<FILES> + payload/SHA256SUMS

# ------------------------------------------------------------------ language
lang_tag="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
if [[ "$lang_tag" == tr* ]]; then LANGF="tr"; else LANGF="en"; fi
# shellcheck source=lang/en.sh
source "$HERE/lang/$LANGF.sh"
m() { local k="$1"; shift; # shellcheck disable=SC2059
  printf "${MSG[$k]}" "$@"; }

# ------------------------------------------------------------------ options
ACTION=""; APPIMAGE=""; SYSTEM=0; GUI=0; YES=0; SILENT=0; MACHINE_PART=0
PROG="${EFNL_PROG:-$(basename "$0")}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    install|uninstall|status) [[ -z "$ACTION" ]] || { m bad_args "$1" >&2; echo >&2; exit 2; }; ACTION="$1" ;;
    --system) SYSTEM=1 ;;
    --gui) GUI=1 ;;
    --yes|-y) YES=1 ;;
    --silent|/silent) YES=1; SILENT=1 ;;
    --machine-part) MACHINE_PART=1 ;;                 # internal: root half of --system
    -h|--help|help) m usage "$PROG"; echo; exit 0 ;;
    -*) m bad_args "$1" >&2; echo >&2; exit 2 ;;
    *) if [[ "$ACTION" == install && -z "$APPIMAGE" ]]; then APPIMAGE="$1"; else m bad_args "$1" >&2; echo >&2; exit 2; fi ;;
  esac
  shift
done
[[ -n "$ACTION" ]] || { m usage "$PROG" >&2; echo >&2; exit 2; }
if [[ $GUI == 1 ]]; then
  if command -v zenity >/dev/null 2>&1; then GUI_TOOL=zenity
  elif command -v kdialog >/dev/null 2>&1; then GUI_TOOL=kdialog
  else GUI=0; fi
  [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || GUI=0
fi

# ------------------------------------------------------------------ locations
TEST_ROOT="${EFNL_TEST_ROOT:-}"
[[ -n "$TEST_ROOT" && -n "${EFNL_TEST_NEED_MB:-}" ]] && NEED_MB="$EFNL_TEST_NEED_MB"
if [[ $SYSTEM == 1 ]]; then
  SYS="${TEST_ROOT:+$TEST_ROOT/sys}"
  PREFIX="$SYS/opt/$ID"
  BIN="$SYS/usr/local/bin/cura-efnl"
  DESKTOP="$SYS/usr/local/share/applications/$ID.desktop"
else
  PREFIX="$HOME/.local/opt/$ID"
  BIN="$HOME/.local/bin/cura-efnl"
  DESKTOP="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$ID.desktop"
fi
STATE="$PREFIX/.efnl"
CONFIG_PROFILE="${XDG_CONFIG_HOME:-$HOME/.config}/cura/5.13"
DATA_PROFILE="${XDG_DATA_HOME:-$HOME/.local/share}/cura/5.13"
SHARED_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/cura/5.13"
OWN_CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/$ID"

# ------------------------------------------------------------------ output
WARNINGS=()
warn() { WARNINGS+=("$1"); }
say() { [[ $SILENT == 1 ]] || printf '%s\n' "$1"; }
report() {  # report <error|warning|info> <text>
  local kind="$1" text="$2"
  if [[ $SILENT == 1 || $MACHINE_PART == 1 ]]; then
    case "$kind" in error) printf 'ERROR: %s\n' "$text" >&2 ;; warning) printf 'WARNING: %s\n' "$text" >&2 ;; *) [[ $SILENT == 1 ]] || printf '%s\n' "$text" ;; esac
    return
  fi
  if [[ $GUI == 1 ]]; then
    if [[ $GUI_TOOL == zenity ]]; then zenity "--$kind" --title="$(m title)" --no-wrap --text="$text" 2>/dev/null || true
    else case "$kind" in error) kdialog --title "$(m title)" --error "$text" ;; warning) kdialog --title "$(m title)" --sorry "$text" ;; *) kdialog --title "$(m title)" --msgbox "$text" ;; esac 2>/dev/null || true; fi
  fi
  case "$kind" in error) printf 'ERROR: %s\n' "$text" >&2 ;; warning) printf 'WARNING: %s\n' "$text" >&2 ;; *) printf '%s\n' "$text" ;; esac
}
die() { report error "$1"; exit 1; }
confirm() {
  [[ $YES == 1 ]] && return 0
  if [[ $GUI == 1 ]]; then
    if [[ $GUI_TOOL == zenity ]]; then zenity --question --title="$(m title)" --no-wrap --text="$1" 2>/dev/null; return; fi
    kdialog --title "$(m title)" --yesno "$1" 2>/dev/null; return
  fi
  [[ -t 0 ]] || return 1
  local answer; printf '%s\n[y/N/e/H] ' "$1"; read -r answer || return 1
  [[ "$answer" =~ ^[yYeE] ]]
}
finish() {  # prints warnings, exits 0
  local w; for w in "${WARNINGS[@]}"; do report warning "$w"; done
  exit 0
}

# ------------------------------------------------------------------ helpers
sha() { sha256sum -- "$1" | cut -d' ' -f1; }
for tool in sha256sum tar awk mktemp find readlink df; do command -v "$tool" >/dev/null 2>&1 || die "$(m missing_tool "$tool")"; done
[[ "$(uname -m)" == x86_64 ]] || die "$(m not_x86 "$(uname -m)")"

no_links() {  # fails if any existing component of the path (below /) is a symlink
  local p="$1" cur=""
  local IFS=/ part
  for part in $p; do
    [[ -z "$part" ]] && continue
    cur="$cur/$part"
    if [[ -L "$cur" ]]; then return 1; fi
    [[ -e "$cur" ]] || break
  done
  return 0
}

running_pid() {  # prints the PID of a process whose executable is inside $1
  local dir exe pid
  dir="$(readlink -f -- "$1" 2>/dev/null || true)"; [[ -n "$dir" ]] || return 1
  for exe in /proc/[0-9]*/exe; do
    pid="${exe#/proc/}"; pid="${pid%/exe}"
    local target; target="$(readlink -- "$exe" 2>/dev/null || true)"
    if [[ "$target" == "$dir/"* ]]; then printf '%s' "$pid"; return 0; fi
  done
  return 1
}
ensure_stopped() { local pid; if pid="$(running_pid "$1")"; then die "$(m running "$1" "$pid")"; fi; }

is_ours() { [[ -f "$1" && ! -L "$1" ]] && grep -qF -- "$MARK" "$1"; }
installed() { [[ -f "$STATE/manifest" && ! -L "$STATE/manifest" ]]; }

payload_hash() {  # payload_hash <index>
  awk -v f="${FILES[$1]}" '{ n=$0; sub(/^[0-9a-f]+  /, "", n); if (n == f) { print $1; exit } }' "$PAYLOAD_DIR/SHA256SUMS"
}
check_payload() {
  [[ -f "$PAYLOAD_DIR/SHA256SUMS" ]] || die "$(m bad_payload SHA256SUMS)"
  local i h
  for i in "${!FILES[@]}"; do
    h="$(payload_hash "$i")"
    [[ -n "$h" && -f "$PAYLOAD_DIR/${FILES[$i]}" && "$(sha "$PAYLOAD_DIR/${FILES[$i]}")" == "$h" ]] || die "$(m bad_payload "${FILES[$i]}")"
  done
}

atomic_write() {  # atomic_write <dest> <mode>  (content on stdin)
  local dest="$1" tmp
  mkdir -p -- "$(dirname -- "$dest")"
  tmp="$(mktemp "$(dirname -- "$dest")/.${ID}.XXXXXX")"
  cat > "$tmp"; chmod "$2" "$tmp"; mv -f -- "$tmp" "$dest"
}

remove_dir() {  # rename first so that a half-deleted folder is never taken for an installation
  local d="$1" doomed
  [[ -e "$d" || -L "$d" ]] || return 0
  if [[ -L "$d" ]]; then rm -f -- "$d"; return 0; fi
  doomed="$(dirname -- "$d")/.$(basename -- "$d").delete-$$-$RANDOM"
  mv -- "$d" "$doomed" && rm -rf -- "$doomed"
}

# ------------------------------------------------------------------ AppImage lookup
find_appimage() {
  local c found=() seen=""
  local dirs=("$HOME/Downloads" "$HOME/İndirilenler" "$HOME/Applications" "$HOME/.local/bin" "$HOME/Desktop" "$HOME/Masaüstü" "/opt")
  if command -v xdg-user-dir >/dev/null 2>&1; then dirs=("$(xdg-user-dir DOWNLOAD 2>/dev/null || true)" "${dirs[@]}"); fi
  say "$(m searching)"
  for c in "${dirs[@]}"; do
    [[ -n "$c" && -d "$c" ]] || continue
    while IFS= read -r -d '' f; do
      local r; r="$(readlink -f -- "$f")"
      [[ "$seen" == *"|$r|"* ]] && continue
      seen+="|$r|"; found+=("$r")
    done < <(find "$c" -maxdepth 2 -type f -iname 'UltiMaker-Cura-5.13.0*linux*.AppImage' -print0 2>/dev/null)
  done
  if [[ ${#found[@]} -eq 0 ]]; then
    if { command -v flatpak >/dev/null 2>&1 && flatpak info com.ultimaker.cura >/dev/null 2>&1; } || command -v cura >/dev/null 2>&1 || [[ -d /snap/cura ]]; then warn "$(m other_cura)"; fi
    local w; for w in "${WARNINGS[@]}"; do report warning "$w"; done
    die "$(m not_found "$PROG")"
  fi
  if [[ ${#found[@]} -eq 1 ]]; then APPIMAGE="${found[0]}"; return; fi
  [[ $YES == 0 && -t 0 ]] || die "$(m several_silent)"
  say "$(m several)"; local i; for i in "${!found[@]}"; do say "  $((i+1))) ${found[$i]}"; done
  local n; printf '%s' "$(m choose)"; read -r n || n=1; n="${n:-1}"
  [[ "$n" =~ ^[0-9]+$ && $n -ge 1 && $n -le ${#found[@]} ]] || die "$(m cancelled)"
  APPIMAGE="${found[$((n-1))]}"
}

# ------------------------------------------------------------------ elevation (--system)
run_machine_part() {  # re-runs this script as root for the machine part
  if [[ -n "$TEST_ROOT" || $EUID == 0 ]]; then return 1; fi   # caller does the work itself
  local args=("$ACTION" --system --machine-part --yes) cmd rc
  [[ $SILENT == 1 ]] && args+=(--silent)
  [[ "$ACTION" == install ]] && args=("$ACTION" "$APPIMAGE" --system --machine-part --yes)
  if command -v sudo >/dev/null 2>&1 && { [[ -t 0 ]] || sudo -n true 2>/dev/null; }; then cmd=(sudo --)
  elif command -v pkexec >/dev/null 2>&1; then cmd=(pkexec)
  elif command -v sudo >/dev/null 2>&1; then cmd=(sudo --)
  else die "$(m no_sudo)"; fi
  set +e
  "${cmd[@]}" env LANG="${LANG:-}" LC_ALL="${LC_ALL:-}" EFNL_PAYLOAD_DIR="$PAYLOAD_DIR" EFNL_PROG="$PROG" bash "$HERE/efnl.sh" "${args[@]}"
  rc=$?
  set -e
  [[ $rc == 0 ]] || die "$(m elev_failed "$rc")"
  return 0
}

# ------------------------------------------------------------------ install
write_launchers() {
  local prefix="$1"
  if [[ -e "$BIN" || -L "$BIN" ]] && ! is_ours "$BIN"; then warn "$(m not_ours "$BIN")"; else
    atomic_write "$BIN" 755 <<EOF
#!/bin/sh
$MARK
# Separate definition cache: see the comment in efnl.sh.
XDG_CACHE_HOME="\${XDG_CACHE_HOME:-\$HOME/.cache}/$ID"
export XDG_CACHE_HOME
exec "$prefix/AppRun" "\$@"
EOF
  fi
  if [[ -e "$DESKTOP" || -L "$DESKTOP" ]] && ! is_ours "$DESKTOP"; then warn "$(m not_ours "$DESKTOP")"; else
    local exec_path="$BIN"; exec_path="${exec_path//\\/\\\\}"; exec_path="${exec_path// /\\s}"
    atomic_write "$DESKTOP" 644 <<EOF
[Desktop Entry]
$MARK
Type=Application
Name=$(source "$HERE/lang/en.sh"; printf '%s' "${MSG[desktop_name]}")
Name[tr]=$(source "$HERE/lang/tr.sh"; printf '%s' "${MSG[desktop_name]}")
Comment=$(source "$HERE/lang/en.sh"; printf '%s' "${MSG[desktop_comment]}")
Comment[tr]=$(source "$HERE/lang/tr.sh"; printf '%s' "${MSG[desktop_comment]}")
Exec="$exec_path" %F
TryExec=$exec_path
Icon=$prefix/cura-icon.png
Terminal=false
Categories=Graphics;3DGraphics;Engineering;
MimeType=model/stl;application/vnd.ms-3mfdocument;application/prs.wavefront-obj;image/bmp;image/gif;image/jpeg;image/png;text/x-gcode;
Keywords=3D;printer;slicer;Cura;
StartupWMClass=UltiMaker-Cura
EOF
    if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database -q "$(dirname -- "$DESKTOP")" 2>/dev/null || true; fi
  fi
}

machine_install() {
  local parent stage="" old="" i
  parent="$(dirname -- "$PREFIX")"
  mkdir -p -- "$parent" 2>/dev/null || die "$(m no_write "$parent")"
  [[ -w "$parent" ]] || die "$(m no_write "$parent")"
  no_links "$PREFIX" || die "$(m foreign_dir "$PREFIX")"
  if [[ -e "$PREFIX" ]] && ! installed; then die "$(m foreign_dir "$PREFIX")"; fi
  ensure_stopped "$PREFIX"
  local free_mb; free_mb="$(df -Pm -- "$parent" | awk 'NR==2 {print $4}')"
  [[ "$free_mb" =~ ^[0-9]+$ ]] || free_mb=0
  (( free_mb >= NEED_MB )) || die "$(m no_space "$parent" "$free_mb" "$NEED_MB")"

  stage="$(mktemp -d "$parent/.$ID.new-XXXXXX")" || die "$(m no_write "$parent")"
  # shellcheck disable=SC2064
  trap "rm -rf -- '$stage'" EXIT
  cleanup_fail() { rm -rf -- "$stage"; trap - EXIT; die "$(m failed_rollback "$1")"; }

  say "$(m extracting)"
  local ai="$APPIMAGE"
  if [[ ! -x "$ai" ]]; then { cp -- "$APPIMAGE" "$stage/app.AppImage" && chmod 700 "$stage/app.AppImage"; } || cleanup_fail "copy"; ai="$stage/app.AppImage"
    [[ "$(sha "$ai")" == "$APPIMAGE_SHA" ]] || cleanup_fail "copy"; fi
  ( cd "$stage" && env -u APPIMAGE -u APPDIR "$ai" --appimage-extract >/dev/null 2>&1 ) || { rm -rf -- "$stage"; trap - EXIT; die "$(m extract_failed)"; }
  rm -f -- "$stage/app.AppImage"
  local root="$stage/squashfs-root"
  [[ -x "$root/AppRun" ]] || { rm -rf -- "$stage"; trap - EXIT; die "$(m layout_bad AppRun)"; }
  for i in "${!FILES[@]}"; do
    [[ -f "$root/${FILES[$i]}" && "$(sha "$root/${FILES[$i]}")" == "${ORIGINAL_HASHES[$i]}" ]] || { rm -rf -- "$stage"; trap - EXIT; die "$(m layout_bad "${FILES[$i]}")"; }
  done

  if [[ -n "$TEST_ROOT" && "${EFNL_TEST_FAIL:-}" == write ]]; then cleanup_fail "test"; fi
  # Backup of the originals + manifest, then replace with the payload.
  mkdir -p "$root/.efnl/backup"
  local manifest=""
  for i in "${!FILES[@]}"; do
    local b="$root/.efnl/backup/${FILES[$i]}"
    mkdir -p -- "$(dirname -- "$b")"
    cp -p -- "$root/${FILES[$i]}" "$b" || cleanup_fail "backup"
    [[ "$(sha "$b")" == "${ORIGINAL_HASHES[$i]}" ]] || cleanup_fail "backup"
    local ph; ph="$(payload_hash "$i")"
    cp -- "$PAYLOAD_DIR/${FILES[$i]}" "$root/${FILES[$i]}.efnl-tmp" || cleanup_fail "write"
    [[ "$(sha "$root/${FILES[$i]}.efnl-tmp")" == "$ph" ]] || cleanup_fail "$(m verify_failed "${FILES[$i]}")"
    if [[ $i == 0 ]]; then chmod 755 "$root/${FILES[$i]}.efnl-tmp"; else chmod 644 "$root/${FILES[$i]}.efnl-tmp"; fi
    mv -f -- "$root/${FILES[$i]}.efnl-tmp" "$root/${FILES[$i]}"
    manifest+="${FILES[$i]}|${ORIGINAL_HASHES[$i]}|$ph"$'\n'
  done
  # The uninstaller lives inside the installation (works even if the .run file is deleted).
  mkdir -p "$root/.efnl/lang"
  cp -- "$HERE/efnl.sh" "$root/.efnl/efnl.sh"; cp -- "$HERE"/lang/*.sh "$root/.efnl/lang/"
  mkdir -p "$root/.efnl/payload"; cp -- "$PAYLOAD_DIR/SHA256SUMS" "$root/.efnl/payload/SHA256SUMS"
  local mode=user; [[ $SYSTEM == 1 ]] && mode=system
  atomic_write "$root/.efnl/uninstall" 755 <<EOF
#!/bin/sh
$MARK
exec bash "$PREFIX/.efnl/efnl.sh" uninstall $([[ $SYSTEM == 1 ]] && echo --system) "\$@"
EOF
  printf 'version=%s\nmode=%s\nappimage_sha256=%s\ninstalled=%s\n' "$VERSION" "$mode" "$APPIMAGE_SHA" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$root/.efnl/info"
  printf '%s' "$manifest" > "$root/.efnl/manifest"   # written last: marks a complete installation
  chmod -R go-w "$root"

  # Swap into place.
  if [[ -e "$PREFIX" ]]; then
    old="$parent/.$ID.old-$$-$RANDOM"
    mv -- "$PREFIX" "$old" || cleanup_fail "rename"
    if ! mv -- "$root" "$PREFIX"; then mv -- "$old" "$PREFIX"; cleanup_fail "rename"; fi
    rm -rf -- "$old"
  elif [[ -n "$TEST_ROOT" && "${EFNL_TEST_FAIL:-}" == swap ]]; then cleanup_fail "test"
  else
    mv -- "$root" "$PREFIX" || cleanup_fail "rename"
  fi
  rm -rf -- "$stage"; trap - EXIT
  # Post-swap verification
  for i in "${!FILES[@]}"; do
    [[ "$(sha "$PREFIX/${FILES[$i]}")" == "$(payload_hash "$i")" ]] || { remove_dir "$PREFIX"; die "$(m failed_rollback "$(m verify_failed "${FILES[$i]}")")"; }
  done
  write_launchers "$PREFIX"
}

do_install() {
  [[ $MACHINE_PART == 1 || $SYSTEM == 0 || -n "$TEST_ROOT" || $EUID != 0 ]] || die "$(m need_root)"
  check_payload
  if [[ -z "$APPIMAGE" ]]; then find_appimage; fi
  APPIMAGE="$(readlink -f -- "$APPIMAGE" 2>/dev/null || printf '%s' "$APPIMAGE")"
  [[ -f "$APPIMAGE" ]] || die "$(m not_found "$PROG")"
  say "$(m checking "$APPIMAGE")"
  [[ "$(sha "$APPIMAGE")" == "$APPIMAGE_SHA" ]] || die "$(m bad_appimage "$APPIMAGE")"
  if [[ $MACHINE_PART == 0 ]]; then
    if installed; then confirm "$(m confirm_update "$PREFIX")" || die "$(m cancelled)"
    else confirm "$(m confirm_install "$PREFIX")" || die "$(m cancelled)"; fi
  fi
  if [[ $SYSTEM == 1 && $MACHINE_PART == 0 ]] && run_machine_part; then :; else machine_install; fi
  [[ $MACHINE_PART == 1 ]] && finish
  report info "$(m installed "$BIN")"
  case ":$PATH:" in *":$(dirname -- "$BIN"):"*) ;; *) warn "$(m path_hint "$(dirname -- "$BIN")")" ;; esac
  finish
}

# ------------------------------------------------------------------ uninstall
machine_uninstall() {
  local i
  if ! installed; then
    # Nothing installed; remove stale launchers of ours only.
    is_ours "$BIN" && rm -f -- "$BIN"
    is_ours "$DESKTOP" && rm -f -- "$DESKTOP"
    return 0
  fi
  no_links "$PREFIX" || die "$(m foreign_dir "$PREFIX")"
  ensure_stopped "$PREFIX"
  # Report files of the copy that changed after installation (they go away with the copy).
  while IFS='|' read -r f _orig ph; do
    [[ -n "$f" ]] || continue
    if [[ ! -f "$PREFIX/$f" || "$(sha "$PREFIX/$f")" != "$ph" ]]; then warn "$(m changed_file "$f")"; fi
  done < "$STATE/manifest"
  is_ours "$BIN" && rm -f -- "$BIN"
  if is_ours "$DESKTOP"; then
    rm -f -- "$DESKTOP"
    if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database -q "$(dirname -- "$DESKTOP")" 2>/dev/null || true; fi
  fi
  # Manifest first: without it the folder is no longer treated as an installation.
  rm -f -- "$STATE/manifest"
  remove_dir "$PREFIX"
}

clean_cfg_file() {  # clean_cfg_file <file> <1 = cura.cfg (setting-key lists too)>
  local f="$1" vis="$2" tmp
  grep -qE "$KEY_LAYERS|$KEY_TAPER" -- "$f" || return 0
  tmp="$(mktemp "$(dirname -- "$f")/.${ID}.XXXXXX")"
  awk -v vis="$vis" -v a="$KEY_LAYERS" -v b="$KEY_TAPER" '
    {
      line = $0; cr = ""
      if (sub(/\r$/, "", line)) cr = "\r"
      if (line ~ "^[ \t]*(" a "|" b ")[ \t]*=") next
      if (vis == 1 && match(line, /^((custom_)?visible_settings|categories_expanded)[ \t]*=[ \t]*/)) {
        head = substr(line, 1, RLENGTH); rest = substr(line, RLENGTH + 1)
        n = split(rest, parts, ";"); out = ""; first = 1
        for (i = 1; i <= n; i++) {
          p = parts[i]; t = p; gsub(/^[ \t]+|[ \t]+$/, "", t)
          if (t == a || t == b) continue
          out = first ? p : out ";" p; first = 0
        }
        line = head out
      }
      print line cr
    }' "$f" > "$tmp" || { rm -f -- "$tmp"; return 1; }
  if cmp -s -- "$tmp" "$f"; then rm -f -- "$tmp"; else chmod --reference="$f" "$tmp" 2>/dev/null || true; mv -f -- "$tmp" "$f"; fi
  if grep -qE "$KEY_LAYERS|$KEY_TAPER" -- "$f"; then warn "$(m unknown_form "$f")"; fi
}

clean_profile() {
  local dir link
  for dir in "$CONFIG_PROFILE" "$DATA_PROFILE" "$SHARED_CACHE"; do
    [[ -e "$dir" ]] || continue
    no_links "$dir" || { report error "$(m profile_link "$dir")"; return 1; }
    link="$(find "$dir" -path "$DATA_PROFILE/plugins" -prune -o -type l -print -quit 2>/dev/null)"
    [[ -z "$link" ]] || { report error "$(m profile_link "$link")"; return 1; }
  done
  if [[ -f "$CONFIG_PROFILE/cura.cfg" ]]; then clean_cfg_file "$CONFIG_PROFILE/cura.cfg" 1; fi
  local f
  for dir in "$CONFIG_PROFILE" "$DATA_PROFILE"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' f; do
      [[ "$f" == "$CONFIG_PROFILE/cura.cfg" ]] && continue
      clean_cfg_file "$f" 0
    done < <(find "$dir" -path "$DATA_PROFILE/plugins" -prune -o -type f -name '*.cfg' -print0)
  done
  # Definition cache: only files that contain the add-on settings (the fdmprinter definition).
  if [[ -d "$SHARED_CACHE" ]]; then
    while IFS= read -r -d '' f; do
      grep -qaF -- "$KEY_LAYERS" "$f" && rm -f -- "$f"
    done < <(find "$SHARED_CACHE" -type f -print0)
  fi
  # The add-on's own cache root.
  if [[ -d "$OWN_CACHE_ROOT" ]] && no_links "$OWN_CACHE_ROOT"; then rm -rf -- "$OWN_CACHE_ROOT"; fi
  return 0
}

do_uninstall() {
  if [[ $MACHINE_PART == 0 && $SYSTEM == 0 ]] && ! installed && ! is_ours "$BIN" && ! is_ours "$DESKTOP"; then
    # Not installed: still clean leftovers in the profile (idempotent), like Windows.
    clean_profile || exit 1
    say "$(m not_installed)"; finish
  fi
  if [[ $MACHINE_PART == 0 ]]; then confirm "$(m confirm_uninstall)" || die "$(m cancelled)"; fi
  if [[ $SYSTEM == 1 && $MACHINE_PART == 0 ]]; then
    ensure_stopped "$PREFIX"
    run_machine_part || machine_uninstall
  else
    machine_uninstall
  fi
  [[ $MACHINE_PART == 1 ]] && finish
  clean_profile || exit 1   # runs as the calling user
  report info "$(m removed)"
  finish
}

# ------------------------------------------------------------------ status
do_status() {
  if ! installed; then say "$(m status_none "$PREFIX")"; exit 1; fi
  local bad="" ver
  ver="$(sed -n 's/^version=//p' "$STATE/info" 2>/dev/null)"
  while IFS='|' read -r f _orig ph; do
    [[ -n "$f" ]] || continue
    [[ -f "$PREFIX/$f" && "$(sha "$PREFIX/$f")" == "$ph" ]] || bad+="$f "
  done < "$STATE/manifest"
  if [[ -z "$bad" ]]; then say "$(m status_installed "$PREFIX" "$ver" "$(m status_intact)")"; exit 0; fi
  say "$(m status_installed "$PREFIX" "$ver" "$(m status_damaged "$bad")")"; exit 1
}

case "$ACTION" in
  install) do_install ;;
  uninstall) do_uninstall ;;
  status) do_status ;;
esac
