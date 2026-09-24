# shellcheck shell=bash
# Türkçe mesajlar. %s yer tutucuları printf ile doldurulur.
# shellcheck disable=SC2034
declare -gA MSG=(
  [title]="Cura 5.13 - Fil Ayağı N Katman"
  [usage]="Kullanım: %s {install [APPIMAGE] | uninstall | status} [--system] [--gui] [--yes|--silent]

  install    Resmi UltiMaker Cura 5.13.0 AppImage dosyasını açar, doğrular ve yamalı bir kopyasını
             \"UltiMaker Cura 5.13 (Fil Ayağı N Katman)\" adıyla kurar. Özgün AppImage değiştirilmez.
  uninstall  Yamalı kopyayı, menü girişini ve komutu kaldırır; eklenti ayarlarını Cura profilinizden ve
             tanım önbelleğinden temizler.
  status     Eklentinin kurulu olup olmadığını ve dosyalarının sağlam olup olmadığını gösterir.

  --system   Tüm kullanıcılar için /opt altına kurar (yalnızca o adım için yönetici yetkisi ister).
  --gui      Soruları ve sonuçları grafik pencereyle gösterir (zenity veya kdialog).
  --yes      Onay sormaz.  --silent: --yes gibi, mesajlar yalnızca stderr'e.
Çıkış kodu: 0 = yapıldı, 1 = yapılmadı veya eksik kaldı (nedeni yazılır)."
  [bad_args]="Bilinmeyen parametre: %s"
  [need_bash]="bash 4 veya daha yenisi gerekir."
  [missing_tool]="Gerekli program bulunamadı: %s"
  [not_x86]="Yalnızca x86_64 (64 bit PC) desteklenir; bu makine %s."
  [searching]="UltiMaker-Cura-5.13.0-linux-X64.AppImage aranıyor ..."
  [not_found]="Resmi UltiMaker Cura 5.13.0 AppImage bulunamadı. UltiMaker-Cura-5.13.0-linux-X64.AppImage dosyasını https://github.com/Ultimaker/Cura/releases/tag/5.13.0 adresinden indirip yolunu verin:
  %s install ~/İndirilenler/UltiMaker-Cura-5.13.0-linux-X64.AppImage"
  [other_cura]="Not: Flatpak, Snap veya dağıtım paketiyle kurulmuş bir Cura bulundu. Bu desteklenmez (dosyaları farklı); yalnızca resmi AppImage desteklenir."
  [several]="Birden fazla Cura 5.13.0 AppImage bulundu:"
  [choose]="Kullanılacak AppImage numarası (Enter = 1): "
  [several_silent]="Birden fazla Cura 5.13.0 AppImage bulundu; yolu açıkça verin."
  [checking]="%s doğrulanıyor ..."
  [bad_appimage]="Bu dosya resmi UltiMaker Cura 5.13.0 Linux AppImage değil (SHA-256 eşleşmiyor); kurulum yapılmadı:
%s
Yalnızca UltiMaker GitHub sürümündeki UltiMaker-Cura-5.13.0-linux-X64.AppImage desteklenir."
  [bad_payload]="Kurulum dosyası bozuk (%s); kurulum yapılmadı. Dosyayı yeniden indirin."
  [confirm_install]="UltiMaker Cura 5.13.0'ın yamalı bir kopyasına ilk N katmanda fil ayağı telafisi kurulsun mu?

Konum: %s
Özgün AppImage değişmez ve kullanılmaya devam edilebilir."
  [confirm_update]="Eklenti zaten kurulu. Yeniden kurulsun (güncellensin) mu?

Konum: %s"
  [confirm_uninstall]="Eklenti, menü girişi ve Cura profilinizdeki eklenti ayarları kaldırılsın mı?"
  [cancelled]="İptal edildi; hiçbir değişiklik yapılmadı."
  [running]="Cura %s içinden çalışıyor (süreç %s). Programı kapatıp yeniden deneyin."
  [foreign_dir]="%s mevcut ama bu eklenti tarafından oluşturulmamış; kurulum yapılmadı. Klasörü taşıyın veya silin, sonra yeniden deneyin."
  [no_space]="%s içinde yeterli boş alan yok (%s MB boş, %s MB gerekli); kurulum yapılmadı."
  [no_write]="%s konumuna yazılamıyor; kurulum yapılmadı."
  [extracting]="AppImage açılıyor ..."
  [extract_failed]="AppImage açılamadı; kurulum yapılmadı."
  [layout_bad]="Açılan AppImage beklenen Cura 5.13.0 dosyasını içermiyor: %s; kurulum yapılmadı."
  [verify_failed]="Yazılan dosya doğrulanamadı: %s; kurulum yapılmadı."
  [failed_rollback]="Kurulum tamamlanamadı (%s); tüm değişiklikler geri alındı."
  [installed]="Eklenti kuruldu. \"UltiMaker Cura 5.13 (Fil Ayağı N Katman)\" uygulamasını menüden veya %s komutuyla başlatın.
Ayarlar: Duvarlar > \"Fil Ayağı Telafi Katman Sayısı\" ve \"Fil Ayağı Kademeli Telafi\" (Uzman görünümü)."
  [path_hint]="Not: %s PATH içinde değil; menü girişini veya tam yolu kullanın."
  [not_ours]="%s zaten mevcut ve bu eklenti tarafından oluşturulmamış; dokunulmadı."
  [not_installed]="Eklenti kurulu değil; yapılacak bir şey yok."
  [changed_file]="Yamalı kopyadaki bu dosya kurulumdan sonra değişmiş; kopyayla birlikte kaldırıldı: %s"
  [removed]="Eklenti kaldırıldı. Profil ayarları ve tanım önbelleği temizlendi."
  [profile_link]="Güvenlik nedeniyle durduruldu: Cura profili sembolik bağlantı içeriyor: %s
Yamalı kopya kaldırıldı; profil temizlenmedi."
  [unknown_form]="Eklenti ayarı bu dosyada tanınmayan bir biçimde kaldı; Cura bunu yok sayar, isterseniz elle silebilirsiniz: %s"
  [need_root]="Bu adım yönetici yetkisi gerektirir. Komutu normal kullanıcı olarak yeniden çalıştırın (sudo'yu kendisi ister)."
  [no_sudo]="--system için yönetici yetkisi gerekiyor ama sudo veya pkexec bulunamadı."
  [elev_failed]="Yönetici onayı verilmedi veya sistem adımı tamamlanamadı (kod %s)."
  [status_installed]="Kurulu (%s): sürüm %s, %s"
  [status_intact]="tüm dosyalar sağlam"
  [status_damaged]="BOZUK: %s"
  [status_none]="Kurulu değil (%s)."
  [user_mode]="kullanıcı"
  [system_mode]="tüm kullanıcılar"
  [desktop_name]="UltiMaker Cura 5.13 (Fil Ayağı N Katman)"
  [desktop_comment]="İlk N katmanda fil ayağı telafili UltiMaker Cura 5.13.0"
)
