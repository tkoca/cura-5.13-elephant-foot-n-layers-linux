# Kaynak kod ve derleme (Linux)

[English](SOURCE_AND_BUILD.md) · [Türkçe](SOURCE_AND_BUILD_tr.md)

`Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run` dosyasını yeniden üretmek için gereken her şey bu depodadır.

## İçerik

| Yol | İçerik |
| --- | --- |
| `patches/CuraEngine-5.13.0.patch` | CuraEngine 5.13.0 `src/slicer.cpp` değişikliği (Windows projesiyle aynı) |
| `patches/Cura-5.13.0.patch` | Üç Cura kaynak dosyasındaki değişiklikler (`fdmprinter.def.json`, Türkçe `.po`, `expert.cfg`); Türkçe `.mo`, yamalı `.po` dosyasından `scripts/po2mo.py` ile derlenir (Windows projesiyle aynı) |
| `scripts/container/Containerfile` | Derleme imajı: Ubuntu 22.04 (sabit digest), GCC 13, Conan 2.32.0, CMake 3.31.6, Ninja 1.13.2, patchelf |
| `scripts/build-curaengine.sh` | CuraEngine'i konteynerde derler (`--unpatched`: kontrol derlemesi) |
| `scripts/check-engine.sh` | İkili dosya kontrolleri: GLIBC ≤ 2.35, GLIBCXX ≤ 3.4.32, yorumlayıcı, RPATH yok, derleme makinesi yolu yok |
| `scripts/apply_patch.py`, `scripts/make_payload.py` | Yamaları uygular; payload'ı üretir (deterministik tar) |
| `scripts/build-installer.sh` | Kendi kendini açan `.run` dosyasını `dist/` içine üretir |
| `installer/` | Kurucu (`efnl.sh`), `.run` başlığı, İngilizce/Türkçe mesajlar |
| `tests/installer-tests.sh` | Kurucu testleri (77 kontrol) |
| `tests/engine/` | Resmi Cura 5.13.0 motoruna karşı dilimleme testleri (26 kontrol) |
| `docs/linux-layout.md` | Resmi 5.13.0 AppImage'ının ölçülmüş yapısı |

## Derleme tercihlerinin nedeni

Resmi AppImage, `CuraEngine`'i kendi içindeki glibc 2.35 ve libstdc++ (GLIBCXX_3.4.32) ile, göreli bir program yorumlayıcısı (`lib64/ld-linux-x86-64.so.2`) üzerinden çalıştırır. Yamalı motor bunlardan daha yenisine ihtiyaç duymamalıdır. Bu yüzden Ubuntu 22.04 (glibc 2.35) üzerinde GCC 13 (GLIBCXX_3.4.32) ile derlenir ve aynı göreli yorumlayıcıyı alır. RPATH olmadan bağlanır, sembolleri silinir. Conan klasörü nötr bir yoldadır (`/opt/efnl`), böylece ikili dosyaya derleme makinesinin hiçbir yolu girmez. Bağımlılıklar UltiMaker Conan yapılandırmasından (`Ultimaker/conan-config`, sabitlenmiş commit) gelir.

## Derleme

Gereksinimler: Linux x86_64, `podman` (rootless olabilir), `python3`, yaklaşık 10 GB boş disk. İlk derleme tüm bağımlılıkları kaynaktan derlediği için 4 çekirdekte (i5-10500) 16 dk 24 sn sürdü; sonraki derlemeler yaklaşık 2 dakika sürer.

```sh
# upstream kaynakları (etiket arşivleri)
curl -LO https://github.com/Ultimaker/CuraEngine/archive/refs/tags/5.13.0.tar.gz && mv 5.13.0.tar.gz CuraEngine-5.13.0.tar.gz
curl -LO https://github.com/Ultimaker/Cura/archive/refs/tags/5.13.0.tar.gz        && mv 5.13.0.tar.gz Cura-5.13.0.tar.gz

podman build -t efnl-build:5.13 -f scripts/container/Containerfile scripts/container
scripts/build-curaengine.sh CuraEngine-5.13.0.tar.gz out          # -> out/CuraEngine, CHECK PASS
scripts/build-installer.sh  Cura-5.13.0.tar.gz out/CuraEngine dist
```

Derleme tekrarlanabilirdir: iki kez derlendiğinde aynı `CuraEngine` ve aynı `.run` dosyası çıkar (sürüm notlarındaki SHA-256 değerleri).

## Testler

```sh
# resmi AppImage, bir kez açılır
./UltiMaker-Cura-5.13.0-linux-X64.AppImage --appimage-extract          # -> squashfs-root/
scripts/build-curaengine.sh --unpatched CuraEngine-5.13.0.tar.gz out   # isteğe bağlı kontrol derlemesi
python3 scripts/make_payload.py Cura-5.13.0.tar.gz out/CuraEngine build

tests/engine/slice-tests.sh squashfs-root out/CuraEngine \
    build/payload/share/cura/resources/definitions/fdmprinter.def.json out/CuraEngine.unpatched
tests/installer-tests.sh UltiMaker-Cura-5.13.0-linux-X64.AppImage build/payload \
    dist/Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run
```

Dilimleme testleri iki motoru da Cura'nın yaptığı gibi AppImage çalışma ortamında çalıştırır. Şunları kontrol eder: katman sayısı 1'de G-code resmi motorla birebir aynı olmalı; N katmanda kademeli telafi açıkken ve kapalıyken katman başına duvar içe kayması doğru olmalı; yamasız kontrol derlemesi resmi motorla birebir aynı G-code üretmeli (böylece farkların yalnızca yamadan geldiği kanıtlanır). Kurucu testleri geçici bir ev klasöründe, gerçek AppImage ile çalışır ve gerçek profile dokunmaz.
