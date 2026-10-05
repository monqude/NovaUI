# Changelog

## 1.14.1
- Karakterin altındaki kişisel can/mana çubuğu varsayılan olarak kapalı (Ayarlar → Birimler'den açılabilir). / Personal health/power bar is now off by default.

## 1.14.0 — ilk herkese açık sürüm / first public release
- Varsayılan yerleşim ve ayarlar yazarın kendi profili (`Layout.lua`). / Default layout and settings are the author's own setup.
- `/nova tr` ve `/nova en` ile dil değiştirme. / Language switch commands.
- Giriş mesajı sadece ilk kurulumda veya güncellemeden sonra. / Login message only on first install or after an update.
- İçe aktarılan profiller kendi dilini korur ve bozuk kodlar ayıklanır. / Imported profiles keep your language; broken codes are sanitized.
- Silah buff'ı uyarısı yeni API'yi kullanıyor (eskiden diğer uyarıları da gizleyebiliyordu). / Weapon buff warning uses the current API (it could hide all other warnings).
- Proc ikonları "hepsini gizle" olayında temizleniyor. / Proc icons clear on "hide all".
- Cooldown ikonları global cooldown'da dönmüyor; kilitleyince soluk hale dönüyor. / Cooldown icons ignore the GCD and restore idle opacity on lock.
- Alt çubuk butondan çıkınca da soluklaşıyor; opaklık ayarı tüm aralıkta çalışıyor. / Bottom bar fades after leaving through a button; full opacity range.
- Meslek cooldown taraması seyreltildi. / Profession cooldown scans are debounced.
- Korece/Çince istemcide font tüm oyuna uygulanmıyor. / Global font skipped on Korean/Chinese clients.
- Minimap başka bir eklentinin `GetMinimapShape` tanımını ezmiyor. / Minimap respects another addon's `GetMinimapShape`.
- MIT lisansı ve tam font lisansı (OFL 1.1) eklendi. / Added MIT license and full OFL 1.1 font license.

## 1.13.0
- Hesap takibi, kişisel bar, kalkan emilimi, kısa buff takibi, nameplate okları / görev ikonu / infaz parlaması, Classic uyarıları.

## 1.12.0 ve öncesi
- İsimli profiller ve dışa/içe aktarma, uyarılar, istenen gridde aksiyon barları, tam genişlik alt çubuk, XP bilgi paneli,
  grid ve yapışmalı düzenleme kipi, portreli birim çerçeveleri, modern nameplate'ler, Türkçe karakterli fontlar ve temel modüller.
