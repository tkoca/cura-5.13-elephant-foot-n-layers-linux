#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # check() evaluates its condition later (eval)
# Scenario tests for installer/efnl.sh (and the .run bundle).
#   tests/installer-tests.sh <official UltiMaker-Cura-5.13.0-linux-X64.AppImage> <payload dir> [run file]
# Every test runs with a fake HOME and EFNL_TEST_ROOT (system paths redirected), so the real
# system is never touched. Needs ~2.5 GB free space in the work folder.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
APPIMAGE="$(readlink -f "$1")"; PAYLOAD="$(readlink -f "$2")"; RUNFILE="${3:+$(readlink -f "$3")}"
WORK="${EFNL_TEST_WORK:-$(mktemp -d "${TMPDIR:-/tmp}/efnl-tests.XXXXXX")}"
EFNL="$REPO/installer/efnl.sh"
FILES=(CuraEngine share/cura/resources/definitions/fdmprinter.def.json share/cura/resources/i18n/tr_TR/fdmprinter.def.json.po
  share/cura/resources/i18n/tr_TR/LC_MESSAGES/fdmprinter.def.json.mo share/cura/resources/setting_visibility/expert.cfg)
ORIG=(949df48874258ff342b5369853515a93d52fa79448aab050d28ceffe16537f4b 8fbbf8b779e806bd8d0b0e2b8b9be17bdd26a575b7ea1875c20481eb2c7e11ee
  ace33455f77ad50ed5d10dbd2f1c2b5732d2c59dcc5e99a9e715ad1bd3f51a85 16dda401341e0805149bdcd674677bf5081413163c6b059255c637187599d3ad
  9b646941fa24799eda46ce207f586ab72687d7b02f837264287bb022b720a4ba)
APPIMAGE_SHA=100f068127b2598167f00ba4db0e0699ded45adf97bbab2d22ff171a1e1ecc40
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); echo "  PASS  $1"; else FAIL=$((FAIL+1)); echo "  FAIL  $1"; fi; }
sha() { sha256sum "$1" | cut -d' ' -f1; }
mapfile -t PH < <(for f in "${FILES[@]}"; do awk -v f="$f" '$2==f{print $1}' "$PAYLOAD/SHA256SUMS"; done)
[[ "$(sha "$APPIMAGE")" == "$APPIMAGE_SHA" ]] || { echo "not the official AppImage"; exit 2; }

reset() {
  chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"; mkdir -p "$WORK"
  export HOME="$WORK/home"; export EFNL_TEST_ROOT="$WORK/root"
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME EFNL_TEST_FAIL EFNL_TEST_NEED_MB
  mkdir -p "$HOME/Downloads" "$EFNL_TEST_ROOT"
  cp "$APPIMAGE" "$HOME/Downloads/UltiMaker-Cura-5.13.0-linux-X64.AppImage"
  chmod 644 "$HOME/Downloads/UltiMaker-Cura-5.13.0-linux-X64.AppImage"   # as downloaded by a browser
  AI="$HOME/Downloads/UltiMaker-Cura-5.13.0-linux-X64.AppImage"
  CFG="$HOME/.config/cura/5.13"; DAT="$HOME/.local/share/cura/5.13"; CCH="$HOME/.cache/cura/5.13"
  PREFIX="$HOME/.local/opt/cura-5.13-efnl"; BIN="$HOME/.local/bin/cura-efnl"; DESK="$HOME/.local/share/applications/cura-5.13-efnl.desktop"
  mkdir -p "$CFG" "$DAT/user" "$DAT/quality_changes" "$DAT/plugins/SomePlugin" "$CCH/definitions/5.13.0"
  printf '[general]\nvisible_settings = xy_offset;elephant_foot_compensation_layers;xy_offset_layer_0;elephant_foot_compensation_taper\ntheme = cura-light\ncategories_expanded = ;alternate_extra_perimeter;elephant_foot_compensation_layers;elephant_foot_compensation_taper;fill_outline_gaps\n' > "$CFG/cura.cfg"
  printf '[general]\r\nversion = 4\r\n\r\n[values]\r\nelephant_foot_compensation_layers = 4\r\nelephant_foot_compensation_taper = True\r\nxy_offset_layer_0 = -0.2\r\n' > "$DAT/user/custom_user.inst.cfg"
  printf '[values]\nelephant_foot_compensation_layers = 3\nlayer_height = 0.2\n' > "$DAT/quality_changes/my_profile.inst.cfg"
  printf 'elephant_foot_compensation_layers = keep\n' > "$DAT/plugins/SomePlugin/plugin.cfg"
  printf 'binary... elephant_foot_compensation_layers ...' > "$CCH/definitions/5.13.0/fdmprinter"
  printf 'no added settings' > "$CCH/definitions/5.13.0/other_printer"
  mkdir -p "$HOME/.cache/cura-5.13-efnl/cura/5.13"; echo x > "$HOME/.cache/cura-5.13-efnl/cura/5.13/containers.db"
}
run() { EFNL_PAYLOAD_DIR="$PAYLOAD" LANG="${TLANG:-en_US.UTF-8}" LC_ALL="" bash "$EFNL" "$@" >"$WORK/out" 2>"$WORK/err" </dev/null; RC=$?; sed 's/^/        /' "$WORK/err"; return 0; }
same_as() { local i; for i in "${!FILES[@]}"; do [[ "$(sha "$1/${FILES[$i]}")" == "$2" || "$2" == "@P" && "$(sha "$1/${FILES[$i]}")" == "${PH[$i]}" || "$2" == "@O" && "$(sha "$1/${FILES[$i]}")" == "${ORIG[$i]}" ]] || return 1; done; }
nostage() { [[ -z "$(find "$HOME/.local/opt" -maxdepth 1 -name '.cura-5.13-efnl*' 2>/dev/null)" ]]; }

echo "T1 fresh install (AppImage found automatically in ~/Downloads)"
reset; run install --yes
check 'exit 0' '[[ $RC == 0 ]]'
check 'five files = payload' 'same_as "$PREFIX" @P'
check 'backup = Cura 5.13.0 originals' 'same_as "$PREFIX/.efnl/backup" @O'
check 'manifest + uninstaller + info' '[[ -f $PREFIX/.efnl/manifest && -x $PREFIX/.efnl/uninstall && $(grep -c version=5.0.0 $PREFIX/.efnl/info) == 1 ]]'
check 'menu entry + command' '[[ -f $DESK && -x $BIN ]] && grep -q "^Exec=\"$BIN\" %F" $DESK && grep -q "Name\[tr\]=UltiMaker Cura 5.13 (Fil Ayağı N Katman)" $DESK'
check 'desktop-file-validate clean' '! command -v desktop-file-validate >/dev/null || desktop-file-validate "$DESK"'
check 'no staging folders left' 'nostage'
check 'user AppImage untouched (content and mode 644)' '[[ $(sha "$AI") == $APPIMAGE_SHA && $(stat -c %a "$AI") == 644 ]]'
check 'rest of Cura intact (AppRun runs)' '[[ -x $PREFIX/AppRun && -f $PREFIX/UltiMaker-Cura ]]'
check 'status exit 0' 'bash "$EFNL" status >/dev/null 2>&1'
check 'launcher uses own cache' 'grep -q "cura-5.13-efnl" "$BIN" && grep -q "exec \"$PREFIX/AppRun\"" "$BIN"'

echo "T2 reinstall over itself"
run install "$AI" --yes
check 'exit 0' '[[ $RC == 0 ]]'
check 'files unchanged' 'same_as "$PREFIX" @P && same_as "$PREFIX/.efnl/backup" @O && nostage'

echo "T3 uninstall removes the copy, cleans profile/cache"
run uninstall --yes
check 'exit 0' '[[ $RC == 0 ]]'
check 'copy, menu entry, command removed' '[[ ! -e $PREFIX && ! -e $DESK && ! -e $BIN ]]'
check 'no leftovers next to the copy' '[[ -z "$(ls -A "$HOME/.local/opt")" ]]'
check 'cura.cfg visibility cleaned, other values kept' '! grep -q elephant_foot "$CFG/cura.cfg" && grep -qx "visible_settings = xy_offset;xy_offset_layer_0" "$CFG/cura.cfg" && grep -qx "theme = cura-light" "$CFG/cura.cfg"'
check 'cura.cfg expanded groups cleaned' 'grep -qx "categories_expanded = ;alternate_extra_perimeter;fill_outline_gaps" "$CFG/cura.cfg"'
check 'user profile cleaned (CRLF kept)' '! grep -q elephant_foot "$DAT/user/custom_user.inst.cfg" && grep -q $'"'"'xy_offset_layer_0 = -0.2\r'"'"' "$DAT/user/custom_user.inst.cfg"'
check 'quality_changes cleaned' '! grep -q elephant_foot "$DAT/quality_changes/my_profile.inst.cfg" && grep -q "layer_height = 0.2" "$DAT/quality_changes/my_profile.inst.cfg"'
check 'plugins folder untouched' 'grep -q elephant_foot "$DAT/plugins/SomePlugin/plugin.cfg"'
check 'stale fdmprinter cache deleted, other kept' '[[ ! -e $CCH/definitions/5.13.0/fdmprinter && -e $CCH/definitions/5.13.0/other_printer ]]'
check 'own cache removed' '[[ ! -e $HOME/.cache/cura-5.13-efnl ]]'
check 'status exit 1' '! bash "$EFNL" status >/dev/null 2>&1'

echo "T4 uninstall when nothing is installed"
run uninstall --yes
check 'exit 0' '[[ $RC == 0 ]]'

echo "T5 wrong AppImage is refused"
reset; printf 'x' >> "$AI"; run install "$AI" --yes
check 'exit 1' '[[ $RC == 1 ]]'
check 'nothing written' '[[ ! -e $HOME/.local/opt && ! -e $DESK && ! -e $BIN ]]'
run install "$WORK/does-not-exist.AppImage" --yes
check 'missing file -> exit 1' '[[ $RC == 1 ]]'

echo "T6 file of the copy changed after install -> removed anyway, WARNING, exit 0"
reset; run install --yes; printf x >> "$PREFIX/CuraEngine"
check 'status reports damage (exit 1)' '! bash "$EFNL" status >/dev/null 2>&1'
run uninstall --silent
check 'exit 0 with WARNING' '[[ $RC == 0 ]] && grep -q "^WARNING:" "$WORK/err"'
check 'copy removed' '[[ ! -e $PREFIX ]]'

echo "T7 foreign folder at the install location is not touched"
reset; mkdir -p "$PREFIX"; echo mine > "$PREFIX/file"
run install --yes
check 'exit 1' '[[ $RC == 1 ]]'
check 'folder untouched' '[[ $(cat "$PREFIX/file") == mine && ! -e $DESK ]]'
rm -rf "$PREFIX"; mkdir -p "$WORK/elsewhere"; mkdir -p "$(dirname "$PREFIX")"; ln -s "$WORK/elsewhere" "$PREFIX"
run install --yes
check 'symlink at install location -> exit 1' '[[ $RC == 1 && -z "$(ls -A "$WORK/elsewhere")" ]]'

echo "T8 Cura running from the copy -> refused"
reset; run install --yes; cp /bin/sleep "$PREFIX/sleep"; "$PREFIX/sleep" 30 & SP=$!; sleep 0.3
run uninstall --yes
check 'uninstall exit 1' '[[ $RC == 1 ]] && grep -qi running "$WORK/err"'
run install --yes
check 'reinstall exit 1' '[[ $RC == 1 ]]'
check 'copy still intact' 'same_as "$PREFIX" @P'
kill $SP 2>/dev/null; wait $SP 2>/dev/null
rm -f "$PREFIX/sleep"; run uninstall --yes
check 'uninstall after closing -> exit 0' '[[ $RC == 0 && ! -e $PREFIX ]]'

echo "T9 failure during install -> nothing left behind"
reset; export EFNL_TEST_FAIL=write; run install --yes; unset EFNL_TEST_FAIL
check 'exit 1' '[[ $RC == 1 ]]'
check 'no copy, no staging, no launchers' '[[ ! -e $PREFIX && ! -e $DESK && ! -e $BIN ]] && nostage'
reset; export EFNL_TEST_FAIL=swap; run install --yes; unset EFNL_TEST_FAIL
check 'failure at final move: exit 1, clean' '[[ $RC == 1 && ! -e $PREFIX ]] && nostage'
reset; run install --yes; export EFNL_TEST_FAIL=write; run install --yes; unset EFNL_TEST_FAIL
check 'failed reinstall keeps the working installation' '[[ $RC == 1 ]] && same_as "$PREFIX" @P && nostage && [[ -x $BIN ]]'
reset; export EFNL_TEST_FAIL=launcher; run install --yes; unset EFNL_TEST_FAIL
check 'failure after swap (launchers): exit 1, copy removed' '[[ $RC == 1 && ! -e $PREFIX ]] && nostage && [[ -z $(ls -A "$HOME/.local/opt" 2>/dev/null) ]]'
reset; run install --yes; export EFNL_TEST_FAIL=launcher; run install --yes; unset EFNL_TEST_FAIL
check 'failure after swap on reinstall: previous installation restored' '[[ $RC == 1 ]] && same_as "$PREFIX" @P && [[ -x $BIN && -f $DESK ]] && nostage && [[ $(ls -A "$HOME/.local/opt") == cura-5.13-efnl ]]'
reset; mkdir -p "$HOME/.local"; : > "$HOME/.local/bin"; run install --yes
check 'HOME/.local/bin is a file: exit 1, nothing installed' '[[ $RC == 1 && ! -e $PREFIX && -f $HOME/.local/bin ]] && nostage'
rm -f "$HOME/.local/bin"

echo "T10 not enough disk space / no write permission"
reset; export EFNL_TEST_NEED_MB=99999999; run install --yes; unset EFNL_TEST_NEED_MB
check 'no space: exit 1, nothing written' '[[ $RC == 1 && ! -e $PREFIX ]] && nostage && grep -q "disk space" "$WORK/err"'
reset; mkdir -p "$HOME/.local/opt"; chmod 555 "$HOME/.local/opt"
if [[ $EUID != 0 ]]; then run install --yes; check 'read-only parent: exit 1' '[[ $RC == 1 && ! -e $PREFIX ]]'; fi
chmod 755 "$HOME/.local/opt"

echo "T11 symlink inside the profile is refused"
reset; run install --yes; mkdir -p "$WORK/outside"; echo 'elephant_foot_compensation_layers = 2' > "$WORK/outside/victim.cfg"
ln -s "$WORK/outside" "$DAT/user/link"
run uninstall --yes
check 'exit 1' '[[ $RC == 1 ]]'
check 'file behind the link untouched' 'grep -q elephant_foot "$WORK/outside/victim.cfg"'
check 'copy removed nevertheless' '[[ ! -e $PREFIX && ! -e $BIN ]]'

echo "T12 Turkish / English messages"
reset; printf x >> "$AI"; TLANG=tr_TR.UTF-8 run install "$AI" --silent
check 'Turkish message' 'grep -q "kurulum yapılmadı" "$WORK/err"'
TLANG=C run install "$AI" --silent
check 'English message' 'grep -q "nothing was installed" "$WORK/err"'

echo "T13 paths with spaces and Turkish characters, custom XDG folders"
reset; mkdir -p "$HOME/İndirilenler/Cura 5.13"; mv "$AI" "$HOME/İndirilenler/Cura 5.13/"; AI="$HOME/İndirilenler/Cura 5.13/UltiMaker-Cura-5.13.0-linux-X64.AppImage"
export XDG_CONFIG_HOME="$HOME/x cfg" XDG_DATA_HOME="$HOME/x data" XDG_CACHE_HOME="$HOME/x cache"
mkdir -p "$XDG_CONFIG_HOME/cura/5.13" "$XDG_CACHE_HOME/cura/5.13"
printf 'visible_settings = a;elephant_foot_compensation_taper;b\n' > "$XDG_CONFIG_HOME/cura/5.13/cura.cfg"
printf 'elephant_foot_compensation_layers' > "$XDG_CACHE_HOME/cura/5.13/fdmprinter"
run install --yes
check 'found in ~/İndirilenler/Cura 5.13/, exit 0' '[[ $RC == 0 ]] && same_as "$PREFIX" @P'
check 'menu entry in XDG_DATA_HOME' '[[ -f "$XDG_DATA_HOME/applications/cura-5.13-efnl.desktop" ]]'
run uninstall --yes
check 'XDG profile cleaned' '[[ $RC == 0 ]] && grep -qx "visible_settings = a;b" "$XDG_CONFIG_HOME/cura/5.13/cura.cfg" && [[ ! -e "$XDG_CACHE_HOME/cura/5.13/fdmprinter" ]]'
check 'menu entry removed' '[[ ! -e "$XDG_DATA_HOME/applications/cura-5.13-efnl.desktop" ]]'
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME

echo "T14 --system mode (system paths redirected by EFNL_TEST_ROOT)"
reset; run install --system --yes
S="$EFNL_TEST_ROOT/sys"
check 'exit 0, copy in /opt' '[[ $RC == 0 ]] && same_as "$S/opt/cura-5.13-efnl" @P'
check 'menu entry + command in /usr/local' '[[ -f $S/usr/local/share/applications/cura-5.13-efnl.desktop && -x $S/usr/local/bin/cura-efnl ]]'
check 'nothing in the user folders' '[[ ! -e $PREFIX && ! -e $BIN && ! -e $DESK ]]'
check 'installed uninstaller passes --system' 'grep -q -- "uninstall --system" "$S/opt/cura-5.13-efnl/.efnl/uninstall"'
run uninstall --system --yes
check 'uninstall exit 0, /opt cleaned' '[[ $RC == 0 && ! -e $S/opt/cura-5.13-efnl && ! -e $S/usr/local/bin/cura-efnl ]]'
check 'profile cleaned in the user account' '! grep -q elephant_foot "$CFG/cura.cfg"'

echo "T15 existing foreign launcher / menu entry is not overwritten"
reset; mkdir -p "$(dirname "$BIN")"; echo 'my own script' > "$BIN"
run install --yes
check 'exit 0 with WARNING' '[[ $RC == 0 ]] && grep -q "^WARNING:" "$WORK/err"'
check 'foreign file kept' '[[ $(cat "$BIN") == "my own script" ]]'
run uninstall --yes
check 'foreign file kept after uninstall' '[[ $(cat "$BIN") == "my own script" ]]'

echo "T16 damaged payload is refused"
reset; cp -r "$PAYLOAD" "$WORK/badpayload"; printf x >> "$WORK/badpayload/share/cura/resources/setting_visibility/expert.cfg"
EFNL_PAYLOAD_DIR="$WORK/badpayload" bash "$EFNL" install --yes >/dev/null 2>"$WORK/err" </dev/null; RC=$?
check 'exit 1, nothing written' '[[ $RC == 1 && ! -e $PREFIX ]]'

echo "T17 installed uninstaller works without the setup file"
reset; run install --yes
LANG=C bash -c "'$PREFIX/.efnl/uninstall' --yes" >/dev/null 2>"$WORK/err" </dev/null; RC=$?
check 'exit 0, removed' '[[ $RC == 0 && ! -e $PREFIX && ! -e $BIN ]]'
check 'profile cleaned' '! grep -q elephant_foot "$CFG/cura.cfg"'

echo "T18 usage errors / non-interactive without --yes"
reset; run frobnicate; check 'unknown action -> exit 2' '[[ $RC == 2 ]]'
run install --yes --bogus; check 'unknown option -> exit 2' '[[ $RC == 2 ]]'
run install; check 'no terminal, no --yes -> cancelled (exit 1), nothing written' '[[ $RC == 1 && ! -e $PREFIX ]]'

if [[ -n "$RUNFILE" ]]; then
  echo "T19 self-extracting .run file"
  reset; LANG=C "$RUNFILE" install "$AI" --yes >/dev/null 2>"$WORK/err" </dev/null; RC=$?
  check '.run install exit 0' '[[ $RC == 0 ]]'
  check 'files = payload SHA of the release' 'same_as "$PREFIX" @P'
  LANG=C "$RUNFILE" status >/dev/null 2>&1; check '.run status exit 0' '[[ $? == 0 ]]'
  LANG=C "$RUNFILE" uninstall --yes >/dev/null 2>"$WORK/err" </dev/null; RC=$?
  check '.run uninstall exit 0' '[[ $RC == 0 && ! -e $PREFIX ]]'
  cp "$RUNFILE" "$WORK/bad.run"; printf 'x' >> "$WORK/bad.run"
  bash "$WORK/bad.run" install "$AI" --yes >/dev/null 2>"$WORK/err" </dev/null; RC=$?
  check 'damaged .run -> exit 1' '[[ $RC == 1 ]] && grep -q damaged "$WORK/err" && [[ ! -e $PREFIX ]]'
  check 'no temp folders left' '[[ -z "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name "cura-efnl.*" -user "$(id -u)" 2>/dev/null)" ]]'
fi

chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"
echo; echo "RESULT: $PASS passed, $FAIL failed"
[[ $FAIL == 0 ]]
