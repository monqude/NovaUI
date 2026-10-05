# NovaUI — WoW Forever için modern arayüz

**World of Warcraft: Forever** (Interface 16001) için sade, modern, hepsi bir arada bir arayüz eklentisi.
Türkçe ve İngilizce. *English below.*

## Kurulum

1. Sağdaki **Releases** kısmından son sürümün **`NovaUI.zip`** dosyasını indir.
2. Zip'i `World of Warcraft\_classic_beta_\Interface\AddOns\` içine çıkar.
   Doğru yol: `...\Interface\AddOns\NovaUI\NovaUI.toc`
   (**Code → Download ZIP** ile indirirsen klasörün adını `NovaUI-main` yerine **`NovaUI`** yap.)
3. Oyunu aç, karakter seçim ekranındaki **AddOns** listesinden NovaUI'yi etkinleştir.
4. Oyunda ayarlar için `/nova`, çerçeveleri taşımak için `/nova unlock` yaz.

İlk açılışta hazır bir yerleşim ve ayarlarla gelir; her şeyi ayarlardan ve düzenleme kipinden değiştirebilirsin.

## Özellikler

| Modül | Ne yapar |
|---|---|
| **Birim çerçeveleri** | Oyuncu, hedef, hedefin hedefi, pet, odak (focus) ve 5 boss çerçevesi. Portreli veya düz görünüm, sınıf renkli can, kalkan emilimi, yumuşak barlar, combo puanları, savaş parıltısı, savaş dışında soluklaşma. İsteğe bağlı karakterinin altında kişisel can/güç çubuğu. |
| **Büyü çubukları** | Oyuncu (gecikme bölgesiyle) ve hedef. Kesilemeyen büyüler gri, kesilenler kırmızı. |
| **Düz vuruş** | Ana el / yan el / menzilli vuruş zamanlayıcısı. |
| **Aksiyon barları** | 8 bar + pet + duruş barı. İstediğin grid (3x4, 2x6, 1x12...), dolum yönü, başlangıç köşesi, boyut, aralık, opaklık, fareyle gelince göster. |
| **XP barı** | Ekranın en üstünde tam genişlikte; dinlenmiş XP, seviye / yüzde / kalan süre gösteren bilgi paneli. Maks seviyede izlenen itibar. |
| **Alt çubuk** | En altta tam genişlikte: oyun menüsü (karakter, büyü kitabı, yetenekler, meslekler, görevler, lonca, grup bul, çantalar...), bölge, altın, çanta, dayanıklılık, arkadaş/lonca, fps/gecikme, saat. |
| **Parti & raid** | Sınıf renkli, menzil soldurmalı güvenli grup çerçeveleri; rol, lider ve hazır kontrolü ikonları. |
| **Buff / debuff** | Stillendirilmiş oyuncu buff'ları; hedefin buff/debuff'ları (debuff'lar dispel tipine göre renkli) ve kendi kısa buff/proc'ların. Savaşta da çalışır. |
| **Nameplate'ler** | Modern görünüm, ayarlanabilir isim/yazı boyutu, can yüzdesi, hedefin iki yanında oklar, görev ikonu, infaz bölgesinde kırmızı parlama. |
| **Uyarılar** | Düşük can uyarısı, eksik buff hatırlatıcı (tıkla, at), cooldown ve proc ikonları, basit savaş yazısı, Classic uyarıları (tamir, yemek/içecek, silah buff'ı, cephane, otomatik saldırı, pet yok). |
| **Hesap takibi** | Tüm karakterlerinin raid kilitleri ve meslek cooldown'ları (Transmute, Mooncloth, Salt Shaker), saatin bilgi kutusunda. |
| **Çanta, chat, tooltip, minimap** | Arama ve sıralamalı tek pencere çanta, sade chat, düz tooltip, kare minimap. Blizzard pencereleri de aynı stile çevrilir. |
| **Düzenleme kipi** | Her çerçeveyi sürükle; grid, yapışma ve hizalama çizgileri. |
| **Profiller** | İsimli profiller kaydet, kodla dışa/içe aktarıp arkadaşlarınla paylaş. |
| **Fontlar** | Türkçe karakterli Inter (varsayılan), Roboto ve Open Sans; istersen tüm oyuna uygulanır. |

## Komutlar

| Komut | |
|---|---|
| `/nova` veya `/novaui` | Ayarlar penceresi |
| `/nova unlock` (`/nova move`) · `/nova lock` | Çerçeveleri taşı / kilitle (çerçeveye sağ tık o çerçeveyi sıfırlar) |
| `/nova reset` | Tüm konumları varsayılana döndür |
| `/nova export` · `/nova import` | Profilini kodla paylaş / arkadaşının kodunu yükle |
| `/nova tr` · `/nova en` | Dil değiştir (arayüz yenilenir) |

## Notlar

- Ayarlar hesaptaki tüm karakterlerde ortaktır. Hesap takibi her karakteri o karakterle bir kez girince kaydeder.
- Blizzard Edit Mode'da her aksiyon barını 12 butonda bırak; yerleşimi NovaUI belirler.
- Düz vuruş zamanlayıcısı için NovaUI oyunun `showSwingTimer` ayarını açar (eklentiyi kaldırsan da açık kalır).
- Forever modern motorda çalışır; savaşta can, güç, isim ve büyü bilgileri eklentilerden gizlenebilir ("secret value").
  NovaUI bu değerlerle hiç hesap yapmaz, motorun güvenli bileşenlerine verir; bu yüzden çerçeveler savaşta da çalışır.
- Zindan içindeki dost nameplate'lere eklentiler dokunamaz, Blizzard görünümünde kalırlar.
- Hata bulursan **Issues** kısmından yaz; mümkünse `/console scriptErrors 1` açıp hata metnini ekle.

## Lisans

Kod: MIT (`LICENSE`). Fontlar: SIL Open Font License 1.1 (`Media/Fonts`).

---

## English

A clean, modern, all-in-one UI for **World of Warcraft: Forever**. The interface starts in Turkish; type **`/nova en`** for English.

**Install:** download `NovaUI.zip` from **Releases** and extract it into `World of Warcraft\_classic_beta_\Interface\AddOns\`
(the path must be `...\AddOns\NovaUI\NovaUI.toc`; with Code → Download ZIP, rename `NovaUI-main` to `NovaUI`), enable it in the AddOns list, then type `/nova`.

**Features:** portrait or flat unit frames (player, target, target of target, pet, focus, boss, personal bar), cast bars and swing timer,
action bars in any grid (3x4, 2x6...), full-width XP bar with info panel, full-width bottom bar (menu, gold, bags, durability, friends,
fps/latency, clock), party and raid frames, buffs/debuffs, modern nameplates (target arrows, quest icon, execute glow), alerts
(low health, missing buffs, cooldowns, procs, repair, food, ammo, pet), account-wide raid lockouts and profession cooldowns,
one-window bags, clean chat/tooltip/minimap, edit mode with grid and snapping, named profiles with export/import,
and fonts with full Turkish characters.

**Commands:** `/nova` settings · `/nova unlock` / `/nova lock` move/lock frames · `/nova reset` reset positions ·
`/nova export` / `/nova import` share profiles · `/nova en` / `/nova tr` language.
