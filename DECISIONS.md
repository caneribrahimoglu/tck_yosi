# TCK YÖSİ — Mimari karar kaydı

29 Ekim 2026: `3a6eeb7` ve tamamlama talebi/şef kararları dilimlerine göre güncellendi. İlk kararların tarihleri korunmuştur; geçmiş kararlar o teslimin kapsamını anlatır.

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

Backend FastAPI, SQLAlchemy, PostgreSQL ve Alembic kullanır. Auth/kullanıcı/ekip entegrasyonu `840b757`'de, ilk teknik bildirim/atama dilimi `31c2d45`'tedir. İkinci teknik dilim başlatma/ilerleme/bekleme-devamı kalıcılaştırır; yalnız tamamlama/onay ve araçlar fake/test implementasyonunda kalır.

Sonuç: mevcut domain portları ve kalıcı yetki/üyelik modeli sonraki dilimlerde korunmalıdır. Migration, transaction ve constraint'ler fake repository invariantlarını korumalıdır.

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

## ADR-014 — Kalıcı teknik yürütme ve güvenli geçişler

Referans: 11 Ekim 2026, `31c2d45` sonrası ikinci teknik backend dilimi. Durum: kodlandı; cihaz üstü manuel kabulü bekleniyor.

Başlatma, ilerleme ve bekleme/devam aynı gerçek repository'ye bağlanır; tamamlama/onay bir sonraki dilimdir. Capability portu execution ile completion'ı ayrı belirtir. Fake lifecycle testlerde korunur, gerçek işlere fake fallback yapılmaz. Yeni paket eklenmez.

Mutasyon, güncel aktif actor, uygun direct/team assignment ve explicit effective operation permission ister. Şef/global read tek başına yazma hakkı vermez. Authorization durum hatalarından önce, ardından actor → sıralı ekipler → iş row lock altında yeniden doğrulanır. Protected grant'ler ekipten sayılmaz; işlem boyunca kilitlenmemiş yeni ekipten grant alınmaz. Revision start/hold/resume sırasında artırılır; eşzamanlı hold/resume ve stale ekran tek valid geçiş üretir. Zaten başlatma typed hatadır ve mevcut metadata değişmez.

Progress note ve hold cycle ayrı tablolardır. ID/yazar/zaman sunucudan gelir. Notta work/actor/submission unique anahtarı retry duplicate'ini önler; Flutter aynı başarısız gönderimde aynı request/key'i korur. Uygulama kapanışı sonrasında taslak/key outbox kalıcılığı bu dilimde yoktur. Tek açık hold partial unique index ile korunur; resume aynı kaydı tamamlar ve ikinci cycle yeni kayıt açar. History edit/delete API'si yoktur.

Geç oturum yanıtları controller generation ile atılır. Detail/capability/history, geçiş sonrası ve dashboard'a dönüşte güncellenir. Gerçek PostgreSQL yarışları yalnız izole disposable test şemasında çalışır; canlı uygulama verisini değiştirmez.

## ADR-015 — Tamamlama talebi ve şef review ayrı küçük dilimler

Referans: 29 Ekim 2026, kullanıcıyla önceki dilimin manuel kabulü sonrası. Durum: 3A talep/history uygulandı; 3B şef review bekliyor.

Talep gönderme ve şef karar verme tek büyük teslim yerine ayrı küçük dilimlerdir. `supportsCompletionRequests` detail/history'yi açar; `supportsCompletion` full review/queue desteğini belirtir ve gerçek adapterda şimdilik false kalır. UI olmayan backend review davranışını taklit etmez; talebin bu aşamada pending kalacağı açıkça belirtilir.

Mevcut `requestTechnicalWorkCompletion` operasyon izni direct veya aktif ekipten gelebilir, fakat current assignment/aktif actor koşulları da gerekir. Global view yazma hakkı vermez. Tek transaction, mevcut sıralı row lock ve captured revision kullanılır. Ayrı history tablosu ID/zaman/actor'ı sunucudan alır; idempotency anahtarı aynı isteğin retry'sini korur, partial unique index aynı işte iki pending talebi önler. Karar alanları gelecekteki dilimle uyumludur fakat bu dilimde review endpoint'i yoktur. Explicit direct review permission ve pending sayaç/queue 3B'ye bırakılır. Yeni paket yoktur.

## ADR-016 — Şef review ve gerçek kuyruk (3B)

Referans: 29 Ekim 2026. Durum: uygulandı, API/widget/yarış QA geçti. ADR-015'teki geçici review-kapalı sınırı kaldırıldı; capability'ler gerçek adapterda true.

Review/list-pending persisted direct `reviewTechnicalWorkCompletion` ister; active/password-complete actor ilk lookup öncesi doğrulanır. Protected grant ekipten sayılamaz; role/global read fallback yoktur. Queue full detail read policy'sini genişletmez; detay navigasyonu mevcut secure read API'sini kullanır. Current chief zaten explicit global read ve review izinlerine sahiptir.

Actor → work → request lock sırası mevcut submission sırasıyla uyumludur. Karar pending request + pending work state üzerinde tek transaction'dır, her karar revision artırır. Approve completed/review zamanına aynı now'ı yazar; reject zorunlu trim/nonblank gerekçe ve inProgress dönüşüdür. History/assignment/start metadata korunur. Karar ID'si immutable olduğundan request decision/state kilidi çift kararın önlenmesi için yeterlidir; review body actor/time/status kabul etmez. Ek migration veya paket yoktur.

Flutter queue sonuçlarını immutable parse eder. Controller doğrulanmış kararı yerel listeden çıkarır; sonrasındaki read hatası başarılı kararı başarısız diye sunmaz. Already-decided stale kuyruğu yeniler, session/generation ve decision başlangıcında queue-generation artışı geç eski yanıtı engeller. Dashboard gerçek pending state'ten beslenir; failure/loading sıfır sayısı gibi gösterilmez, review yetkisi olmayanda count/queue gizlidir. Operasyon merkezindeki literal Onay Kuyruğu gerçek navigation callback'ini kullanır.

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
