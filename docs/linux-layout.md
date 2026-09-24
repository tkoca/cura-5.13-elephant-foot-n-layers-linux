# Faz 1 ölçüm raporu — UltiMaker Cura 5.13.0 Linux AppImage (24.09.2026)

## Paket
- Dosya: UltiMaker-Cura-5.13.0-linux-X64.AppImage, 334154232 bayt
- SHA-256: 100f068127b2598167f00ba4db0e0699ded45adf97bbab2d22ff171a1e1ecc40 (GitHub digest ile birebir)
- GPG: "Good signature" — Ultimaker Build Server <monolith@ultimaker.com>,
  parmak izi 1889 EAED 2DB9 3BF7 DFFB 3CA6 C1A1 B910 69C4 AF59 (keyserver.ubuntu.com; keys.openpgp.org kullanıcı kimliksiz döndürüyor)
- İmza tarihi 28.05.2026. `--appimage-extract` FUSE'suz çalıştı; çıkarılmış boyut 1022 MB.

## İç yapı (squashfs-root/)
- Motor: `CuraEngine` (kökte). SHA-256 949df48874258ff342b5369853515a93d52fa79448aab050d28ceffe16537f4b
- Resources: `share/cura/resources/`
- Başlatıcı: `AppRun` (appimage-builder ELF) + `AppRun.env`; asıl program `UltiMaker-Cura`
- İkon: `cura-icon.png`, `cura-icon.svg`; desktop: `com.ultimaker.cura.desktop`

## Değişecek 5 dosya — orijinal SHA-256
| Dosya | SHA-256 | Windows kaynağıyla |
|---|---|---|
| CuraEngine | 949df488…537f4b | (platforma özgü) |
| share/cura/resources/definitions/fdmprinter.def.json | 8fbbf8b7…7e11ee | AYNI |
| share/cura/resources/i18n/tr_TR/fdmprinter.def.json.po | ace33455…f51a85 | AYNI |
| share/cura/resources/i18n/tr_TR/LC_MESSAGES/fdmprinter.def.json.mo | 16dda401…99d3ad | Windows ORIGINALS'ta yok → ölçüldü |
| share/cura/resources/setting_visibility/expert.cfg | 9b646941…720a4ba | AYNI |

## Resmi motor
- ELF64 PIE, stripped, yorumlayıcı GÖRELİ: `lib64/ld-linux-x86-64.so.2` (AppRun cwd'yi runtime/compat yapınca çözülür)
- NEEDED: libArcus.so, libpolyclipping.so.22, libtbbmalloc_proxy.so.2, libtbb.so.12, libssl.so.3, libcrypto.so.3,
  libstdc++.so.6, libm.so.6, libgcc_s.so.1, libc.so.6, ld-linux-x86-64.so.2 → protobuf/gRPC/abseil STATİK gömülü
- RUNPATH: GitHub runner'ın `/home/runner/.conan2/...` yolları (resmi ikilide de yol sızıntısı var — bizimki temiz olacak)
- En yüksek sembol: GLIBC_2.35, GLIBCXX_3.4.32; AppImage kendi glibc 2.35 + libstdc++ (3.4.32) taşıyor (runtime/compat)
- Sonuç: ana sistemin glibc'si belirleyici DEĞİL; motor AppImage'ın glibc 2.35'iyle yüklenir. Hedef tavan: GLIBC ≤ 2.35, GLIBCXX ≤ 3.4.32
  → derleme ubuntu:22.04 (glibc 2.35) + GCC 13 (GLIBCXX 3.4.32) konteynerinde.
- `CuraEngine help` → "Cura_SteamEngine version 5.13.0" (AppDir kütüphaneleriyle). Sistem libc'siyle çalıştırılınca
  `__tunable_is_initialized` hatası → motor daima AppDir ortamında çağrılmalı (testler de öyle).

## Profil yolları (kaynak: UM/Resources.py, Cura 5.13 içinden)
- Config: `${XDG_CONFIG_HOME:-~/.config}/cura/5.13/` (cura.cfg burada)
- Data:   `${XDG_DATA_HOME:-~/.local/share}/cura/5.13/` (user/, quality_changes/, plugins/ ...)
- Cache:  `${XDG_CACHE_HOME:-~/.cache}/cura/5.13/` (Windows'taki `\cache` alt klasörü Linux'ta YOK)
- Kanıt düzeyi: kaynak kod. GUI'nin gerçek dosya oluşumuyla teyidi (Faz 1/4) kullanıcı onayı bekliyor.
