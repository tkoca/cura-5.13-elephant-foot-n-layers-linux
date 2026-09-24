# Source and build (Linux)

[English](SOURCE_AND_BUILD.md) · [Türkçe](SOURCE_AND_BUILD_tr.md)

Everything needed to rebuild `Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run` is in this repository.

## Contents

| Path | Content |
| --- | --- |
| `patches/CuraEngine-5.13.0.patch` | Change to `src/slicer.cpp` of CuraEngine 5.13.0 (identical to the Windows project) |
| `patches/Cura-5.13.0.patch` | Changes to three Cura resource files (`fdmprinter.def.json`, Turkish `.po`, `expert.cfg`); the Turkish `.mo` is compiled from the patched `.po` by `scripts/po2mo.py` (identical to the Windows project) |
| `scripts/container/Containerfile` | Build image: Ubuntu 22.04 (pinned digest), GCC 13, Conan 2.32.0, CMake 3.31.6, Ninja 1.13.2, patchelf |
| `scripts/build-curaengine.sh` | Builds CuraEngine in the container (`--unpatched` for a control build) |
| `scripts/check-engine.sh` | Binary checks: GLIBC ≤ 2.35, GLIBCXX ≤ 3.4.32, interpreter, no RPATH, no build-host paths |
| `scripts/apply_patch.py`, `scripts/make_payload.py` | Apply the patches; build the payload (deterministic tar) |
| `scripts/build-installer.sh` | Builds the self-extracting `.run` file into `dist/` |
| `installer/` | Installer (`efnl.sh`), `.run` header, English/Turkish messages |
| `tests/installer-tests.sh` | Installer tests (77 checks) |
| `tests/engine/` | Slicing tests (26 checks) against the official Cura 5.13.0 engine |
| `docs/linux-layout.md` | Measured layout of the official 5.13.0 AppImage |

## Why these build choices

The official AppImage runs `CuraEngine` with its own bundled glibc 2.35 and libstdc++ (GLIBCXX_3.4.32) through a relative program interpreter (`lib64/ld-linux-x86-64.so.2`). The patched engine must not need anything newer, therefore it is built on Ubuntu 22.04 (glibc 2.35) with GCC 13 (GLIBCXX_3.4.32) and gets the same relative interpreter. It is linked without RPATH, stripped, and the Conan home is a neutral path (`/opt/efnl`) so no build-machine path ends up in the binary. Dependencies come from the UltiMaker Conan configuration (`Ultimaker/conan-config`, pinned commit).

## Build

Requirements: Linux x86_64, `podman` (rootless is fine), `python3`, about 10 GB of free disk space. The first build compiles all dependencies from source and took 16 min 24 s on 4 cores (i5-10500); later builds take about 2 minutes.

```sh
# upstream sources (tag archives)
curl -LO https://github.com/Ultimaker/CuraEngine/archive/refs/tags/5.13.0.tar.gz && mv 5.13.0.tar.gz CuraEngine-5.13.0.tar.gz
curl -LO https://github.com/Ultimaker/Cura/archive/refs/tags/5.13.0.tar.gz        && mv 5.13.0.tar.gz Cura-5.13.0.tar.gz

podman build -t efnl-build:5.13 -f scripts/container/Containerfile scripts/container
scripts/build-curaengine.sh CuraEngine-5.13.0.tar.gz out          # -> out/CuraEngine, CHECK PASS
scripts/build-installer.sh  Cura-5.13.0.tar.gz out/CuraEngine dist
```

The build is reproducible: building twice gives the same `CuraEngine` and the same `.run` file (same SHA-256 values as in the release notes).

## Tests

```sh
# official AppImage, extracted once
./UltiMaker-Cura-5.13.0-linux-X64.AppImage --appimage-extract          # -> squashfs-root/
scripts/build-curaengine.sh --unpatched CuraEngine-5.13.0.tar.gz out   # optional control build
python3 scripts/make_payload.py Cura-5.13.0.tar.gz out/CuraEngine build

tests/engine/slice-tests.sh squashfs-root out/CuraEngine \
    build/payload/share/cura/resources/definitions/fdmprinter.def.json out/CuraEngine.unpatched
tests/installer-tests.sh UltiMaker-Cura-5.13.0-linux-X64.AppImage build/payload \
    dist/Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run
```

The slicing tests run both engines inside the AppImage runtime, like Cura does. They check that layer count 1 gives G-code identical to the official engine, the per-layer wall inset for N layers with and without gradual compensation, and that the unpatched control build gives G-code identical to the official engine (so differences come only from the patch). The installer tests run in a temporary home folder with the real AppImage and never touch the real profile.
