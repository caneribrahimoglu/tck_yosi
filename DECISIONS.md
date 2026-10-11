# TCK YÖSİ — Mimari karar kaydı

11 Ekim 2026: `840b757` ve bu teslimdeki ilk teknik backend dilimine göre güncellendi. İlk kararların tarihleri korunmuştur; geçmiş kararlar o teslimin kapsamını anlatır.

## ADR-001 — Feature-first mimari

Tarih: 9 Temmuz 2026. Durum: kabul edildi, uygulanıyor.

Her iş modülü kendi domain, veri erişimi ve presentation sorumluluklarını taşır. Ortak tema/tokenlar `core`, ortak UI bileşenleri `shared` altında bulunur. Mevcut dashboard klasörleri için sırf aynı görünüm uğruna toplu taşıma yapılmaz.

Sonuç: bağımsız test ve geliştirme kolaylaşır; feature'lar birbirlerinin implementasyonlarına bağlanmamalıdır.

## ADR-002 — İlk backend olarak Firebase

Tarih: 9 Temmuz 2026. Durum: güncel planın yerini ADR-007 aldı.

İlk plan Firebase Authentication/Firestore/Storage kullanmaktı. Mevcut uygulamada bu entegrasyon kurulmadı. Kodda FastAPI/PostgreSQL backend oluşturulduğundan Firebase artık güncel geliştirme varsayımı değildir. Eski karar, proje geçmişini açıklamak için saklanmıştır.

## ADR-003 — Repository/port sınırı

Tarih: 9 Temmuz 2026. Durum: kabul edildi, uygulanıyor.

UI veriye controller üzerinden ulaşır; controller domain arayüzüne bağlıdır. Fake adapter geçici geliştirme aracıdır. API'ye geçişte presentation/domain'i backend teknolojisine bağlamak yerine adapter değiştirilir.

Repository yalnız veri getirmez: mevcut fake implementasyonlarda authorization, geçiş, benzersizlik ve history bütünlüğü kurallarının nihai sınırıdır. Gerçek API'de bu doğrulamalar sunucuya taşınmalı; istemci kontrolü tek başına yeterli sayılmamalıdır.

## ADR-004 — Composition root ve kaynak sahipliği

Tarih: 9 Temmuz 2026; mevcut uygulamayla açıklama güncellendi. Durum: kabul edildi.

`main.dart` minimal kalır; `app/app.dart` uygulama kurulumu ve paylaşılan bağımlılıkları sahiplenir. Repository/controller'lar sayfalarda yeniden oluşturulmaz. Root, sahip olduğu controller'ları dispose eder.

Sonuç: aynı uygulama ömründe state/geçmiş paylaşılır. Logout authenticated route ağacını kaldırırken uygulama repository'lerini yeniden oluşturmak zorunda değildir.

## ADR-005 — Tek sorumluluk ve okunabilirlik

Tarih: 9 Temmuz 2026. Durum: kabul edildi.

Bir dosyanın görevi açık olmalıdır. Büyük ekranlar focused widget'lara bölünür; iş mantığı controller/domain/repository sınırında tutulur. Kullanıcı eğitimi ve bakım açısından gereksiz soyutlama/framework eklenmez.

## ADR-006 — Proje hafızasının bakımı

Tarih: 9 Temmuz 2026. Durum: kabul edildi; 11 Ekim 2026'da belgeler güncellendi.

README mevcut ürünü ve çalıştırmayı; ROADMAP tamamlanan/önerilen işleri; ARCHITECTURE mevcut yapıyı; CHANGELOG teslim geçmişini; DECISIONS önemli kararları anlatır. Yeni bir mimari/ürün dilimi bu belgelerle birlikte değerlendirilir. Test sonucu tarih/referans olmadan güncel başarı gibi sunulmaz.

## ADR-007 — FastAPI/PostgreSQL backend temeli

Referans: `45c352d`, `7f7cc6c`. Durum: kodda uygulanmış yön.

Backend FastAPI, SQLAlchemy, PostgreSQL ve Alembic kullanır. Auth/kullanıcı/ekip entegrasyonu `840b757`'de; ilk teknik bildirim/atama backend dilimi mevcut çalışma ağacındadır. Araç ve kalan teknik lifecycle fake/test implementasyonunda kalır.

Sonuç: domain API'leri ve kalıcı yetki/üyelik modeli sonraki dilimlerde tasarlanmalıdır. Migration, transaction ve constraint'ler fake repository invariantlarını korumalıdır.

## ADR-008 — Rol, permission ve üyeliği ayırma

Referans: TCK-TEAM-001 ve teknik operasyon dilimleri. Durum: Flutter ve backend'de ayrı direct permission / ekip / üyelik modeli mevcut.

Rol ekran seçimi için kullanılır; explicit permission ve aktif assignment/üyelik erişimi iş yapma hakkını belirler. Doğrudan kullanıcı ve aktif ekip yetkileri birleşir; explicit deny yoktur. Korunan sistem yetkileri ekip üzerinden devredilmez.

Ekipler ayrı üyelik kayıtlarıyla tutulur; `AppUser` içine team ID listesini source of truth olarak gömmeyiz. Feature sınırları port/adaptor ile korunur.

## ADR-009 — Kimliği ve işlem geçmişini koruma

Referans: TCK-TEAM-001, TCK-TECH-007…010, TCK-VEHICLE-005…008. Durum: uygulanıyor.

Ekiplerde hard delete yerine archive/restore kullanılır. Restore pasif döner. Teknik işin ekip ataması başlatan kullanıcıya çevrilmez; başlatan/zaman ayrı saklanır. İlerleme, bekleme/devam, tamamlama ve araç operasyon geçmişleri ayrı kayıtlarla korunur.

Domain kayıtlarına display name yazılmaz; isimler mevcut kullanıcı/ekip kaynaklarından presentation sınırında çözülür.

## ADR-010 — Güvenli işlem ve eşzamanlılık sınırı

Referans: TCK-TECH-007…011 ve repository review düzeltmeleri. Durum: fake repository'lerde uygulanıyor.

Actor erişimi state-specific hatadan önce doğrulanır. Mutasyon current source of truth'a göre yeniden kontrol edilir; çift submission/kararlar in-flight guard ve typed hatalarla ele alınır. UI yalnız yükleme ve güvenli hata mesajı sunar.

Detay/history okuma actor gerektirir; global okuma explicit permission ile verilir. Eski geniş liste okuma borcu backend tasarımında ayrıca kapatılmalıdır. Bellek içi guard gerçek sunucuda transaction/constraint yerine geçmez.

## ADR-011 — Gerçek auth adapterı ve güvenli oturum

Referans: 11 Ekim 2026 tarihli auth entegrasyonu. Durum: uygulandı; gerçek giriş/restore/logout manuel kabulü tamamlandı.

Varsayılan giriş `ApiAuthService` olur; fake auth yalnız testlerde injection ile kullanılır. Native platformlarda token/expiry secure storage'da, web'de yalnız bellekte tutulur. Parola saklanmaz; restore `/me` ile doğrulanır. Refresh/revocation bu dilime eklenmez. Süre dolumu ve unauthorized yanıt root logout/navigasyon yolunu kullanır. Zorunlu parola değişimi tamamlanmadan dashboard açılmaz.

Yetkiler backend User JSON alanında explicit saklanır. Migration en eski bootstrap şef hesabına sabit başlangıç grant listesini yazar; diğer hesaplar boş kalır. Runtime rolü şef olmak kendiliğinden grant üretmez. Gerçek kullanıcı ID'si demo kişiye çevrilmez; demo/önceki actor isimleri yalnız display için tutulur ve aktif yetkili actor olarak dönmez.

`http` ve `flutter_secure_storage`, ağ ve güvenli native saklama için eklendi. Ayrı state-management framework eklenmedi. Debug yerel HTTP kullanabilir; release/profile HTTPS URL gerektirir. Web kalıcı oturumu gelecekte backend HttpOnly-cookie kararıyla ele alınabilir.

## Henüz karara bağlanmamış başlıklar

- Refresh ve server-side logout/revocation; kalıcı web oturumu.
- Kurum/şeflik veri izolasyonu ve denetim kayıtları.
- Domain migration sırası ve eşzamanlılık/transaction ayrıntıları.
- Offline veri, senkronizasyon, dosya depolama, bildirim ve üretim dağıtımı.

ROADMAP'teki öneriler, bu başlıklar için kabul edilmiş ayrıntılı teknik karar sayılmaz.

## ADR-012 — Şef kullanıcı yönetimi ve kalıcı ekip temeli

Referans: 11 Ekim 2026, kullanıcı onayıyla şefin kullanıcı yönetimi yapması. Durum: kodlandı; kullanıcı cihaz manuel kontrolünde çalıştığını doğruladı.

`manageUsers` başlangıç şefine doğrudan verilir, role göre otomatik runtime grant yoktur. Kullanıcı yönetimi operational hesaplarla sınırlıdır; kendi/başka yönetici hesabını kilitleme ve yeni yönetici yaratma bu ekrandan yapılmaz. Direct grant'ler şefin sahip olduklarıyla sınırlıdır; `manageUsers`/`manageTeamPermissions` bu ekran üzerinden başka hesaba devredilmez. Yönetim yetkileri hiçbir durumda ekipten devredilemez.

Team ve TeamMembership ayrı PostgreSQL tablolarıdır. Normalize ad/üyelik çifti DB'de benzersizdir; archive/restore ile ID ve geçmiş bağları korunur. Üyelik çıkarma soft-deactivate, yeniden ekleme reactivation'dır. Etkin izin yalnız current session için backend'de direct izinler + aktif üyeliklerin aktif/arşivlenmemiş ekip izinlerinden hesaplanır; legacy protected ekip izinleri fail-closed filtrelenir.

Kullanıcı/ekip API'leri aynı auth transport'u kullanır. İş/araç fake adapterlarını bu dilimde topluca değiştirmeyiz. Eski fake isimler yalnız display compatibility kaynağıdır; gerçek hesap/üyelik yaratılmaz. Açık teknik iş arşivleme guard'ının sunucu karşılığı, teknik operasyon backend dilimine bırakılır; yerel guard geçici olarak korunur.

## ADR-013 — Teknik backend'e aşamalı ve fail-closed geçiş

Referans: 11 Ekim 2026, `840b757` sonrası teknik backend ilk dilimi. Durum: kodlandı; kullanıcı cihaz üstü manuel kontrolünde çalıştığını doğruladı.

İlk dilim bildirim, actor-scope liste/detay, gerçek mühendis/ekip ataması ve audit ile sınırlıdır. Tam fake lifecycle korunur ama gerçek işlerde kullanılmaz; capability portu ve hazırlık mesajı bu sınırı açıklar. İleride başlatma/ilerleme/bekleme, ardından tamamlama/onay ayrı backend dilimleri olacaktır. Yeni framework/paket eklenmez.

Liste ve detail/history aynı read scope'u uygular; kendi bildirimini okuma creator'a açıktır, global okuma direct viewAllTechnicalWork gerektirir. Global atama için direct assignTechnicalWork + viewAllTechnicalWork gerekir; delegable team grant veya rol tek başına tüm işleri yeniden atama hakkı vermez. Request-body creator/permission/status/system alanları reddedilir.

Actor/submission unique anahtarı retry duplicate'lerini önler. UI aynı form tekrarında key'i korur; yeniden açılışta taslak/outbox henüz yoktur. Atama captured revision ve row lock ile güncel veriye karşı doğrulanır; iki hedef aynı anda saklanamaz. Atama geçmişi immutable audit kayıtlarında tutulur. Ekip archive ile assignment aynı hedef lock sırasını kullanır; server open-work guard nihai otoritedir. Üç gerçek PostgreSQL concurrency testi ayrı test şemasında uygulama verisine dokunmadan çalışır.
