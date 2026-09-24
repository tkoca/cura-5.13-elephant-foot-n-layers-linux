# shellcheck shell=bash
# English messages. %s placeholders are filled with printf.
# shellcheck disable=SC2034
declare -gA MSG=(
  [title]="Cura 5.13 - Elephant Foot N Layers"
  [usage]="Usage: %s {install [APPIMAGE] | uninstall | status} [--system] [--gui] [--yes|--silent]

  install    Extracts the official UltiMaker Cura 5.13.0 AppImage, checks it and installs a patched copy
             as \"UltiMaker Cura 5.13 (Elephant Foot N Layers)\". The original AppImage is not changed.
  uninstall  Removes the patched copy, its menu entry and command, and removes the add-on settings from
             your Cura profile and the definition cache.
  status     Shows whether the add-on is installed and whether its files are intact.

  --system   Install for all users in /opt (asks for administrator rights for that step only).
  --gui      Ask and report with graphical dialogs (zenity or kdialog).
  --yes      Do not ask for confirmation.  --silent: --yes, messages only on stderr.
Exit code: 0 = done, 1 = not done or incomplete (a message explains why)."
  [bad_args]="Unknown argument: %s"
  [need_bash]="bash 4 or newer is required."
  [missing_tool]="Required program not found: %s"
  [not_x86]="Only x86_64 (64-bit PC) is supported; this machine is %s."
  [searching]="Searching for UltiMaker-Cura-5.13.0-linux-X64.AppImage ..."
  [not_found]="The official UltiMaker Cura 5.13.0 AppImage was not found. Download UltiMaker-Cura-5.13.0-linux-X64.AppImage from https://github.com/Ultimaker/Cura/releases/tag/5.13.0 and pass its path:
  %s install ~/Downloads/UltiMaker-Cura-5.13.0-linux-X64.AppImage"
  [other_cura]="Note: a Cura from Flatpak, Snap or a distribution package was found. It is not supported (different files); only the official AppImage is."
  [several]="Several Cura 5.13.0 AppImages were found:"
  [choose]="Number of the AppImage to use (Enter = 1): "
  [several_silent]="Several Cura 5.13.0 AppImages were found; pass the path explicitly."
  [checking]="Checking %s ..."
  [bad_appimage]="This file is not the official UltiMaker Cura 5.13.0 Linux AppImage (SHA-256 does not match); nothing was installed:
%s
Only UltiMaker-Cura-5.13.0-linux-X64.AppImage from the UltiMaker GitHub release is supported."
  [bad_payload]="The setup file is damaged (%s); nothing was installed. Download it again."
  [confirm_install]="Install elephant foot compensation for the first N layers into a patched copy of UltiMaker Cura 5.13.0?

Location: %s
The original AppImage stays unchanged and can still be used."
  [confirm_update]="The add-on is already installed. Reinstall (update) it?

Location: %s"
  [confirm_uninstall]="Remove the add-on, its menu entry and its settings from your Cura profile?"
  [cancelled]="Cancelled; nothing was changed."
  [running]="Cura is running from %s (process %s). Close it and try again."
  [foreign_dir]="%s exists but was not created by this add-on; nothing was installed. Move or remove it and try again."
  [no_space]="Not enough free disk space in %s (%s MB free, %s MB needed); nothing was installed."
  [no_write]="Cannot write to %s; nothing was installed."
  [extracting]="Extracting the AppImage ..."
  [extract_failed]="The AppImage could not be extracted; nothing was installed."
  [layout_bad]="The extracted AppImage does not contain the expected Cura 5.13.0 file %s; nothing was installed."
  [verify_failed]="A file could not be verified after writing: %s; nothing was installed."
  [failed_rollback]="Installation failed (%s); all changes were rolled back."
  [installed]="The add-on is installed. Start \"UltiMaker Cura 5.13 (Elephant Foot N Layers)\" from the application menu or with the command %s.
Settings: Walls > \"Elephant Foot Compensation Layer Count\" and \"Elephant Foot Gradual Compensation\" (Expert visibility)."
  [path_hint]="Note: %s is not in your PATH; use the menu entry or the full path."
  [not_ours]="%s already exists and was not created by this add-on; it was left unchanged."
  [not_installed]="The add-on is not installed; nothing to do."
  [changed_file]="This file of the patched copy changed after installation; it was removed together with the copy: %s"
  [removed]="The add-on was removed. The profile settings and the definition cache were cleaned."
  [profile_link]="Stopped for safety: the Cura profile contains a symbolic link: %s
The patched copy was removed; the profile was not cleaned."
  [unknown_form]="An add-on setting remains in this file in an unrecognised form; Cura ignores it and you may delete it by hand: %s"
  [need_root]="This step needs administrator rights. Run the command again as a regular user (it asks for sudo itself)."
  [no_sudo]="Administrator rights are needed for --system, but neither sudo nor pkexec is available."
  [elev_failed]="Administrator approval was not given or the system step failed (code %s)."
  [status_installed]="Installed (%s): version %s, %s"
  [status_intact]="all files intact"
  [status_damaged]="DAMAGED: %s"
  [status_none]="Not installed (%s)."
  [user_mode]="user"
  [system_mode]="all users"
  [desktop_name]="UltiMaker Cura 5.13 (Elephant Foot N Layers)"
  [desktop_comment]="UltiMaker Cura 5.13.0 with elephant foot compensation for the first N layers"
)
