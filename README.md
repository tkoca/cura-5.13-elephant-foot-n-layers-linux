# Cura 5.13.0 — Elephant Foot Compensation for N Layers (Linux)

[English](README.md) · [Türkçe](README_tr.md)

An unofficial add-on for **UltiMaker Cura 5.13.0 on Linux x86_64** (the official AppImage). It applies *Initial Layer Horizontal Expansion* to the first **N** printed layers instead of only the first one, and can optionally step the value back to the normal *Horizontal Expansion* over those layers.

This is the Linux counterpart of [cura-5.13-elephant-foot-n-layers](https://github.com/tkoca/cura-5.13-elephant-foot-n-layers) (Windows). Both use the same patches, the same settings and the same resource files.

> This is a community project. It is not made, endorsed or supported by UltiMaker.

## Settings

Two settings are added directly below *Initial Layer Horizontal Expansion* (category *Walls*). They are part of the *Expert* visibility preset; you can also find them with the settings search.

| Setting | Default | Effect |
| --- | --- | --- |
| Elephant Foot Compensation Layer Count | `1` | How many of the first printed layers use *Initial Layer Horizontal Expansion*. `1` is exactly the standard Cura behaviour. Cura shows a warning above 20. |
| Elephant Foot Gradual Compensation | off | Steps the value from *Initial Layer Horizontal Expansion* toward *Horizontal Expansion* over those layers. Only shown when the layer count is greater than 1. |

Example: *Initial Layer Horizontal Expansion* `-0.20 mm`, *Horizontal Expansion* `0.00 mm`, layer count `4`:

| Printed layer | Gradual off | Gradual on |
| --- | --- | --- |
| 1 | -0.20 | -0.20 |
| 2 | -0.20 | -0.15 |
| 3 | -0.20 | -0.10 |
| 4 | -0.20 | -0.05 |
| 5 and above | 0.00 | 0.00 |

All N layers are compensated; the layer after them uses the normal value. If *Horizontal Expansion* is not zero, the steps lead toward that value instead of 0.

In the Turkish interface the settings are called *Fil Ayağı Telafi Katman Sayısı* and *Fil Ayağı Kademeli Telafi*.

## Requirements

- Linux on x86_64 (64-bit PC). Any distribution that runs the official Cura 5.13.0 AppImage.
- The official **`UltiMaker-Cura-5.13.0-linux-X64.AppImage`** from the [UltiMaker Cura 5.13.0 release](https://github.com/Ultimaker/Cura/releases/tag/5.13.0)
  (SHA-256 `100f068127b2598167f00ba4db0e0699ded45adf97bbab2d22ff171a1e1ecc40`).
- `bash` 4+, `tar`, `sha256sum` and the other standard GNU tools. Python, FUSE and administrator rights are **not** needed.
- About 1.3 GB of free disk space (the extracted Cura).

Not supported: Cura from Flathub (`com.ultimaker.cura`), Snap, AUR or distribution packages — their files differ and cannot be verified.

## Install

1. Download `Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run` from [Releases](../../releases) and check that its SHA-256 matches the value in the release notes:
   ```sh
   sha256sum Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run
   ```
2. Close Cura.
3. Install (pass the path of the AppImage; without a path it is searched in `~/Downloads`, `~/İndirilenler`, `~/Applications`, `~/Desktop`, `~/Masaüstü`, `~/.local/bin` and `/opt`):
   ```sh
   chmod +x Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run
   ./Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run install ~/Downloads/UltiMaker-Cura-5.13.0-linux-X64.AppImage
   ```
4. Start **UltiMaker Cura 5.13 (Elephant Foot N Layers)** from the application menu, or run `cura-efnl`.

How it works: an AppImage is read-only, so the installer checks the AppImage (SHA-256), extracts it, checks that the five affected files are exactly the files of UltiMaker Cura 5.13.0, backs them up, replaces them and installs this patched copy next to your Cura. **Your AppImage is not changed** — you can keep using it as the normal Cura. The patched copy uses its own definition cache, so both can be used side by side. The installation is atomic: if anything fails, nothing is left behind (and an existing installation keeps working).

Messages are in Turkish when `LANG` starts with `tr`, otherwise in English.

## Uninstall

```sh
~/.local/opt/cura-5.13-efnl/.efnl/uninstall        # works without the .run file
# or
./Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run uninstall
```

- The patched copy, its menu entry and the `cura-efnl` command are removed. Your AppImage was never changed.
- The two settings are removed from your Cura profile (`~/.config/cura/5.13` and `~/.local/share/cura/5.13`, including your saved custom profiles; `plugins/` is not touched), and outdated setting-cache files are deleted (`~/.cache/cura/5.13`). `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_CACHE_HOME` are respected.
- If a file of the patched copy changed after installation you get a warning naming it.
- For safety the profile is not touched if it contains a symbolic link.

Remove the add-on before switching to another Cura version.

## What is changed on your computer

| Location | Content |
| --- | --- |
| `~/.local/opt/cura-5.13-efnl/` | Extracted Cura 5.13.0 AppImage with the five files below replaced |
| `…/CuraEngine` | Patched CuraEngine 5.13.0 |
| `…/share/cura/resources/definitions/fdmprinter.def.json` | The two new settings |
| `…/share/cura/resources/i18n/tr_TR/fdmprinter.def.json.po` and `LC_MESSAGES/fdmprinter.def.json.mo` | Turkish names and descriptions |
| `…/share/cura/resources/setting_visibility/expert.cfg` | Settings listed in the Expert preset |
| `…/.efnl/` | Backup of the original files, manifest (SHA-256), uninstaller |
| `~/.local/share/applications/cura-5.13-efnl.desktop` | Menu entry |
| `~/.local/bin/cura-efnl` | Start command |
| `~/.cache/cura-5.13-efnl/` | Definition cache of the patched copy |

With `--system` the copy goes to `/opt/cura-5.13-efnl`, the menu entry to `/usr/local/share/applications` and the command to `/usr/local/bin` (for all users).

### Command line

```text
./Cura-5.13-…-x86_64.run install [APPIMAGE] [--system] [--gui] [--yes|--silent]
./Cura-5.13-…-x86_64.run uninstall          [--system] [--gui] [--yes|--silent]
./Cura-5.13-…-x86_64.run status             [--system]
```

- `--system`: install for all users. Only the part in `/opt` and `/usr/local` runs as root (via `sudo`, or `pkexec`); the profile cleanup always runs as your own user. Do not start the installer itself with `sudo`.
- `--gui`: questions and results in dialogs (`zenity` or `kdialog`, if installed).
- `--yes`: no questions. `--silent`: like `--yes`, messages only on standard error (warnings as `WARNING: …`).
- Exit code `0` means success (possibly with warnings); `1` means nothing or not everything was done; `2` means a usage error.

## Source and build

Everything needed to rebuild the installer is in this repository: the patches, the installer, the build scripts (containerised), and the tests. See [SOURCE_AND_BUILD.md](SOURCE_AND_BUILD.md).

## License

GNU Affero General Public License v3.0 or later ([LICENSE](LICENSE)), the license of CuraEngine. The Cura resource files are © UltiMaker, LGPL-3.0-or-later. The source code for the `CuraEngine` included in the installer is UltiMaker CuraEngine 5.13.0 plus [`patches/CuraEngine-5.13.0.patch`](patches/CuraEngine-5.13.0.patch), built with [`scripts/build-curaengine.sh`](scripts/build-curaengine.sh). The installer does not contain or redistribute UltiMaker Cura itself; it modifies your own copy of the official AppImage.

Use at your own risk; try it on a small calibration print first.
