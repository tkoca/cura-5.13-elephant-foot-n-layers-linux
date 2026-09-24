# Cura 5.13.0 — İlk N Katmanda Fil Ayağı Telafisi (Linux)

[English](README.md) · [Türkçe](README_tr.md)

Bu, **Linux x86_64 üzerindeki UltiMaker Cura 5.13.0** (resmi AppImage) için resmi olmayan bir eklentidir. *İlk Katmanın Yatay Genişlemesi* değerini yalnızca ilk katmana değil, basılan ilk **N** katmana uygular. İsteğe bağlı olarak değeri bu katmanlar boyunca adım adım normal *Yatay Büyüme* değerine döndürür.

Bu depo, [cura-5.13-elephant-foot-n-layers](https://github.com/tkoca/cura-5.13-elephant-foot-n-layers) (Windows) projesinin Linux karşılığıdır. İkisi de aynı yamaları, aynı ayarları ve aynı kaynak dosyalarını kullanır.

> Bu bir topluluk projesidir. UltiMaker bu projeyi geliştirmemiştir, onaylamamıştır ve desteklememektedir.

## Ayarlar

*İlk Katmanın Yatay Genişlemesi* ayarının hemen altına (*Duvarlar* kategorisi) iki ayar eklenir. Ayarlar *Uzman* görünürlük ön ayarında yer alır; ayar aramasıyla da bulunabilir.

| Ayar | Varsayılan | Etkisi |
| --- | --- | --- |
| Fil Ayağı Telafi Katman Sayısı | `1` | *İlk Katmanın Yatay Genişlemesi* değerinin basılan ilk kaç katmanda kullanılacağı. `1`, standart Cura davranışıyla birebir aynıdır. 20'nin üzerinde Cura uyarı gösterir. |
| Fil Ayağı Kademeli Telafi | kapalı | Değeri bu katmanlar boyunca *İlk Katmanın Yatay Genişlemesi*'nden *Yatay Büyüme*'ye doğru adım adım değiştirir. Yalnızca katman sayısı 1'den büyükken görünür. |

Örnek: *İlk Katmanın Yatay Genişlemesi* `-0,20 mm`, *Yatay Büyüme* `0,00 mm`, katman sayısı `4`:

| Basılan katman | Kademeli kapalı | Kademeli açık |
| --- | --- | --- |
| 1 | -0,20 | -0,20 |
| 2 | -0,20 | -0,15 |
| 3 | -0,20 | -0,10 |
| 4 | -0,20 | -0,05 |
| 5 ve sonrası | 0,00 | 0,00 |

N katmanın hepsi telafi edilir; bunlardan sonraki katman normal değeri kullanır. *Yatay Büyüme* sıfır değilse adımlar 0'a değil, o değere doğru ilerler.

İngilizce arayüzde ayarların adı *Elephant Foot Compensation Layer Count* ve *Elephant Foot Gradual Compensation*'dır.

## Gereksinimler

- x86_64 (64 bit PC) Linux. Resmi Cura 5.13.0 AppImage'ı çalıştıran her dağıtım.
- [UltiMaker Cura 5.13.0 sürümündeki](https://github.com/Ultimaker/Cura/releases/tag/5.13.0) resmi **`UltiMaker-Cura-5.13.0-linux-X64.AppImage`**
  (SHA-256 `100f068127b2598167f00ba4db0e0699ded45adf97bbab2d22ff171a1e1ecc40`).
- `bash` 4+, `tar`, `sha256sum` ve diğer standart GNU araçları. Python, FUSE ve yönetici yetkisi **gerekmez**.
- Yaklaşık 1,3 GB boş disk alanı (açılmış Cura).

Desteklenmeyenler: Flathub (`com.ultimaker.cura`), Snap, AUR veya dağıtım paketleriyle kurulan Cura — dosyaları farklıdır ve doğrulanamaz.

## Kurulum

1. [Releases](../../releases) sayfasından `Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run` dosyasını indirin ve SHA-256 değerinin sürüm notlarındakiyle aynı olduğunu kontrol edin:
   ```sh
   sha256sum Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run
   ```
2. Cura'yı kapatın.
3. Kurun (AppImage yolunu verin; yol verilmezse `~/Downloads`, `~/İndirilenler`, `~/Applications`, `~/Desktop`, `~/Masaüstü`, `~/.local/bin` ve `/opt` içinde aranır):
   ```sh
   chmod +x Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run
   ./Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run install ~/İndirilenler/UltiMaker-Cura-5.13.0-linux-X64.AppImage
   ```
4. Uygulama menüsünden **UltiMaker Cura 5.13 (Fil Ayağı N Katman)** uygulamasını başlatın ya da `cura-efnl` komutunu çalıştırın.

Nasıl çalışır: AppImage salt okunurdur. Kurulum önce AppImage'ı SHA-256 ile doğrular ve açar. Etkilenen beş dosyanın UltiMaker Cura 5.13.0 dosyalarıyla birebir aynı olduğunu kontrol eder, bunları yedekler ve değiştirir. Sonra yamalı kopyayı Cura'nızın yanına kurar. **AppImage dosyanız değiştirilmez**; onu normal Cura olarak kullanmaya devam edebilirsiniz. Yamalı kopya kendi tanım önbelleğini kullandığı için ikisi yan yana çalışır. Kurulum ya tamamen yapılır ya hiç yapılmaz: bir adım başarısız olursa geride hiçbir şey kalmaz, mevcut kurulum da çalışmaya devam eder.

`LANG` değeri `tr` ile başlıyorsa mesajlar Türkçe, değilse İngilizcedir.

## Kaldırma

```sh
~/.local/opt/cura-5.13-efnl/.efnl/uninstall        # .run dosyası olmadan da çalışır
# veya
./Cura-5.13-Elephant-Foot-N-Layers-Linux-x86_64.run uninstall
```

- Yamalı kopya, menü girişi ve `cura-efnl` komutu kaldırılır. AppImage dosyanız zaten hiç değiştirilmemiştir.
- İki ayar Cura profilinizden (`~/.config/cura/5.13` ve `~/.local/share/cura/5.13`, kaydettiğiniz özel profiller dahil; `plugins/` klasörüne dokunulmaz) silinir, eski ayar önbelleği dosyaları (`~/.cache/cura/5.13`) temizlenir. `XDG_CONFIG_HOME`, `XDG_DATA_HOME` ve `XDG_CACHE_HOME` dikkate alınır.
- Yamalı kopyadaki bir dosya kurulumdan sonra değiştiyse, o dosyanın adı uyarıyla bildirilir.
- Güvenlik için profil sembolik bağlantı içeriyorsa profile dokunulmaz.

Başka bir Cura sürümüne geçmeden önce eklentiyi kaldırın.

## Bilgisayarınızda değişenler

| Konum | İçerik |
| --- | --- |
| `~/.local/opt/cura-5.13-efnl/` | Aşağıdaki beş dosyası değiştirilmiş, açılmış Cura 5.13.0 AppImage'ı |
| `…/CuraEngine` | Yamalı CuraEngine 5.13.0 |
| `…/share/cura/resources/definitions/fdmprinter.def.json` | İki yeni ayar |
| `…/share/cura/resources/i18n/tr_TR/fdmprinter.def.json.po` ve `LC_MESSAGES/fdmprinter.def.json.mo` | Türkçe adlar ve açıklamalar |
| `…/share/cura/resources/setting_visibility/expert.cfg` | Uzman ön ayarında listelenen ayarlar |
| `…/.efnl/` | Özgün dosyaların yedeği, bildirim dosyası (SHA-256), kaldırıcı |
| `~/.local/share/applications/cura-5.13-efnl.desktop` | Menü girişi |
| `~/.local/bin/cura-efnl` | Başlatma komutu |
| `~/.cache/cura-5.13-efnl/` | Yamalı kopyanın tanım önbelleği |

`--system` ile kopya `/opt/cura-5.13-efnl` altına, menü girişi `/usr/local/share/applications` altına, komut ise `/usr/local/bin` altına kurulur (tüm kullanıcılar için).

### Komut satırı

```text
./Cura-5.13-…-x86_64.run install [APPIMAGE] [--system] [--gui] [--yes|--silent]
./Cura-5.13-…-x86_64.run uninstall          [--system] [--gui] [--yes|--silent]
./Cura-5.13-…-x86_64.run status             [--system]
```

- `--system`: tüm kullanıcılar için kurar. Yalnızca `/opt` ve `/usr/local` adımı root olarak çalışır (`sudo` veya `pkexec` ile); profil temizliği her zaman kendi kullanıcınızla yapılır. Kurucunun kendisini `sudo` ile başlatmayın.
- `--gui`: sorular ve sonuçlar pencereyle gösterilir (`zenity` veya `kdialog` kuruluysa).
- `--yes`: soru sormaz. `--silent`: `--yes` gibi çalışır, mesajları yalnızca standart hata çıktısına yazar (uyarılar `WARNING: …`).
- Çıkış kodu `0` başarı demektir (uyarı olabilir). `1`, işlemin yapılmadığını veya tamamlanmadığını; `2`, hatalı kullanımı gösterir.

## Kaynak kod ve derleme

Kurulum dosyasını yeniden üretmek için gereken her şey bu depodadır: yamalar, kurucu, konteynerde çalışan derleme betikleri ve testler. Ayrıntılar için [SOURCE_AND_BUILD_tr.md](SOURCE_AND_BUILD_tr.md) dosyasına bakın.

## Lisans

CuraEngine'in lisansı olan GNU Affero General Public License v3.0 veya sonrası geçerlidir ([LICENSE](LICENSE)). Cura kaynak dosyaları © UltiMaker, LGPL-3.0-or-later lisanslıdır. Kurulumdaki `CuraEngine` dosyasının kaynak kodu, UltiMaker CuraEngine 5.13.0 ile [`patches/CuraEngine-5.13.0.patch`](patches/CuraEngine-5.13.0.patch) yamasıdır; [`scripts/build-curaengine.sh`](scripts/build-curaengine.sh) ile derlenir. Kurulum dosyası UltiMaker Cura'nın kendisini içermez ve dağıtmaz; sizin indirdiğiniz resmi AppImage'ın bir kopyasını değiştirir.

Kullanım sorumluluğu size aittir. Önce küçük bir kalibrasyon baskısıyla deneyin.
