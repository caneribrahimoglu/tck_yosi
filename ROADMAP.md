# TCK YÖSİ — Yol haritası ve devam noktası

Son güncelleme: 11 Ekim 2026. Kod referansı: `7f7cc6c`. Bu belge tamamlanan kodu ve önerilen işleri ayırır; sonraki maddeler kendiliğinden onaylanmış görev kapsamı değildir.

## Mevcut aşama

Gerçek auth manuel kabulü tamamlandı: giriş, yeniden açılışta oturum koruma ve çıkış sonrası oturum temizliği kullanıcı tarafından doğrulandı. Kullanıcı/ekip/üyelik/yetki yönetimi FastAPI/PostgreSQL'e bağlandı ve kullanıcı manuel testte çalıştığını doğruladı. Teknik işler ve araçlar demo repository'lerde; sonraki geçiş bunları kalıcılaştırmak.

## Tamamlanan dilimler

| Referans | Teslim edilen kapsam |
| --- | --- |
| Flutter / UI temeli | Feature-first yapı, Violet tema/tokenlar, ortak bileşenler, responsive ekranlar. |
| AUTH ve TECH-001…005 | Rol/yetki temeli, dashboardlar, saha bildirimi domain/repository/controller/UI akışı. |
| TCK-TECH-006 | Şefin bildirimi inceleme, önceliklendirme ve kullanıcı/ekibe ataması. |
| TCK-TEAM-001 | Ekip, ayrı üyelik kayıtları, yetkiler, aktif/pasif, arşiv/geri yükleme ve güvenlik kuralları. |
| TCK-TECH-007 | Aktif ekip üyesine iş görünürlüğü; güvenli başlatma ve başlatan/zaman bilgisi. |
| TCK-TECH-008 | Yetkili detay okuma ve ilerleme notu geçmişi. |
| TCK-TECH-009 | Tamamlama talebi, şef onay kuyruğu, onay/red ve geçmiş. |
| TCK-TECH-010 | Gerekçeli beklemeye alma, devam etme ve döngü geçmişi. |
| TCK-TECH-011 | Eşzamanlı ilerleme gönderimi korumasının düzeltilmesi. |
| TCK-NAV-001 | Şef modül ana sayfası, gerçek modül navigasyonu ve logout route temizliği. |
| TCK-VEHICLE-001 | Araç domain'i, filo listesi, sayaç, arama ve filtreler. |
| TCK-VEHICLE-002 | Responsive araç detay akışı. |
| TCK-VEHICLE-003 | Güvenli araç kayıt/ekleme akışı. |
| TCK-VEHICLE-004 | Araç düzenleme ve durum yönetimi. |
| TCK-VEHICLE-005 | Araç personel ataması ve atama geçmişi. |
| TCK-VEHICLE-006 | Araç teslim ve kontrol akışı. |
| TCK-VEHICLE-007 | Arıza ve bakım kayıtları. |
| TCK-VEHICLE-008 | Araç arıza değerlendirme akışı. |
| Backend temeli (`45c352d`) | FastAPI, PostgreSQL/SQLAlchemy, Alembic kullanıcı migration'ı, ilk şef oluşturma aracı. |
| Backend auth (`7f7cc6c`) | Giriş, JWT, mevcut kullanıcı, parola değiştirme ve güvenlik testleri. |

“Tamamlandı” bu dilimin kodunun mevcut olduğunu belirtir; üretim kurulumu veya gerçek backend entegrasyonu tamamlandı demek değildir.

## Açık işler ve mevcut sınırlar

- API auth adapterı uygulamanın varsayılan servisidir. Gerçek `sef` hesabıyla giriş/restore/logout manuel kabulü tamamlandı.
- İş ve araç verileri uygulama belleğinde. Kullanıcılar ve ekip/üyelik/yetki verileri PostgreSQL'de kalıcıdır.
- Şef `manageUsers` doğrudan yetkisiyle kullanıcı oluşturma, aktiflik, geçici parola ve izin yönetimi yapar. Ekip yönetimi ayrı `manageTeamPermissions` sınırındadır. Yönetim yetkileri ekipten devredilemez.
- Zorunlu parola değişimi Flutter'da uygulanıyor; gelecekteki korumalı iş uçları sunucudaki dependency'yi kullanmalıdır.
- Android/masaüstünde güvenli kalıcı token oturumu mevcut. Web tokenı yalnız bellekte. Refresh token ve sunucu logout/revocation henüz yok.
- Personel Yönetimi şefe gerçek kullanıcı yönetimini açar. Yönetici hesaplarını oluşturma/değiştirme, profil/rol düzenleme, mesai/izin ve personel iş süreçleri bu dilimde yok.
- Kullanıcı ve ekip ekranlarının cihaz üstü manuel kontrolünde kullanıcı sorun olmadığını bildirdi. Otomatik API/controller/widget testleri mevcut; isim normalizasyonu ve üyelik benzersizliği DB constraint'leriyle korunur.
- Açık teknik işi olan ekibi arşivleme kontrolü fake iş adapterında kalır; sunucular/cihazlar arası garanti teknik işler backend'e taşınınca kurulmalıdır.
- Fotoğraf/dosya ekleri, çevrimdışı senkronizasyon, canlı takip ve üretim dağıtımı mevcut dilimlerin dışında.

## Önerilen devam sırası

1. **Teknik operasyonları kalıcılaştır:** ilk dilim bildirim, yetkili liste/detay okuma ve gerçek kullanıcı/ekibe atama; ikinci dilim başlatma/ilerleme/bekleme; üçüncü dilim tamamlama ve şef onayı. Mevcut kullanıcı/ekip tesliminin manuel kontrolü tamamlandı.
2. **Oturumun sonraki ihtiyaçlarını seç:** mevcut access-token oturumu dışında refresh/revocation veya web HttpOnly-cookie akışı gerekiyorsa ayrı dilim tanımla.
3. **Kullanıcı ve ekip temeli eklendi:** migration/API ve Flutter adapterları hazır; sonrasında ihtiyaç varsa profil/rol düzenleme ve kapsamlı audit ayrı dilimdir.
4. **Kalan domain'leri backend'e taşı:** teknik operasyonlar ve araçlar için migration/API/repository adapterları; assignment, geçmiş, arşiv guard ve eşzamanlılık veritabanında korunmalı. Gerçek kişiler/ekipler hazır olduğu için teknik operasyonlar uygun sonraki adaydır.
5. **Yeni ürün kapsamını seç:** personel, yakıt/kilometre takibi, raporlar ve bildirimler. Her biri ayrı ve test edilebilir dikey dilim olarak tanımlanmalı.

Bu sıra mevcut bağımlılıklara göre öneridir. Ayrıntılı görev kimliği ve kabul kriterleri uygulama başlamadan netleştirilir.

## Uzun vadeli ürün başlıkları

- Müdürlük/şeflik kapsamı ve çoklu kurum izolasyonu.
- Personel, mesai, izin ve günlük görevlendirme.
- Yakıt, kilometre ve bakım planlama.
- Yönetim raporları, Excel/PDF dışa aktarma.
- Bildirimler, GPS/harita ve canlı araç takibi.
- Dosya ekleri, audit kayıtları, offline veri ve senkronizasyon.

Bunlar ürün yönüdür; bu belgede takvim veya teslim taahhüdü yoktur.

## Her teslimde proje hafızasını güncelle

- Tamamlanan dilimi ve commit referansını CHANGELOG'a ekle.
- ROADMAP'teki ilgili işi tamamlandı/açık olarak güncelle.
- Mimari değiştiyse ARCHITECTURE ve DECISIONS'ı güncelle.
- Gerçek test sonuçlarını kaydet; eski bir test sayısını güncel sonuç gibi kullanma.
- Demo veri ile kalıcı backend davranışını açıkça ayır.
