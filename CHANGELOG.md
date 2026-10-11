# TCK YÖSİ — Değişiklik geçmişi

## 11 Ekim 2026 — Teknik backend dilim 2 (`31c2d45` sonrası)

- Başlatma, ilerleme notu, beklemeye alma/devam gerçek API ve PostgreSQL'e taşındı; ekip ataması ve orijinal başlangıç metadata'sı korunur.
- Ayrı TechnicalWorkProgressNote/HoldRecord tabloları ve `e8a7152c4906` migration'ı; yerel PostgreSQL'e uygulandı, Alembic model karşılaştırması temiz.
- Aktif current actor/atama/etkin operasyon izni doğrulaması durum hatalarından önce yapılır. Global chief read yazma izni değildir; team/work row lock altında tekrar doğrulanır.
- Başlatma ve hold/resume revision koruması; notlarda idempotent retry, tek açık hold DB index'i, silinmeyen döngü geçmişi.
- API adapter/capability split, güvenli detail/hold controller state ve logout temizliği; mevcut Violet detail/engineer ekranları bağlandı. Tamamlama/onay kapalı kalır; araçlar demo.
- API/controller/widget testleri: şef atama → mühendis başlat/not/bekle/devam → logout → şef read-only geçmiş, isimler ve dar ekran.
- PostgreSQL'de iki yetkili start, yetkisiz/yetkili start yarışı, duplicate hold/resume, hold-resume ve progress-hold yarışları ile duplicate not testi.

11 Ekim 2026 doğrulaması: 296 Flutter testi ve PostgreSQL yarış testleri dahil 153 backend testi geçti; Dart format, Flutter analyze, git diff --check ve Alembic check temiz. Android debug APK derlendi; yerel API yeniden başlatıldı, API/DB health ve yeni uçlar doğrulandı. Cihaz üstü manuel kabul henüz bekleniyor; kullanıcı gün sonunda stage/commit/push işlemlerini onayladı. İlk tüm-test koşusunda bir mevcut araç testi başarısız oldu; ilgili dosya tek başına ve ardından tam paket yeniden çalıştırıldığında tüm testler geçti. Araç kodu bu dilimde değiştirilmedi.

## 11 Ekim 2026 — İlk teknik operasyon backend dilimi (`31c2d45`)

- Saha bildirimleri, yetkili liste/detay ve gerçek mühendis/ekip ataması FastAPI/PostgreSQL'e taşındı; fake iş seed'i gerçek veriye aktarılmaz.
- TechnicalWork ve append-only TechnicalWorkAssignment tabloları; `d1b9e206f734` migration'ı yerel veritabanına uygulandı, Alembic model karşılaştırması temiz.
- Actor/effective create permission, global direct read/assign izinleri, current target/state validation, revision conflict ve aynı actor/submission için idempotency.
- Açık iş ekip archive guard'ı artık sunucu transaction sınırında; gerçek PostgreSQL'de duplicate report, duplicate assignment ve archive/assignment yarış testleri.
- ApiTechnicalWorkRepository composition, güvenli paralel load, logout sonrası iş state temizliği, isim çözümleme ve retry key koruması.
- Gerçek işlerde start/progress/hold/completion fake fallback yok; capability ve hazırlık mesajları. Araçlar demo kalır; mevcut izole fake lifecycle testleri korunur.
- Tam şef bildirim/ekip ataması → logout → mühendis görünürlüğü/detay akışı ve dar ekran testi eklendi.

11 Ekim 2026 doğrulaması: 287 Flutter testi, PostgreSQL yarış testleri dahil 92 backend testi geçti. Dart format, Flutter analyze, diff kontrolü ve Android debug APK derlemesi temiz. Kullanıcı yeni dilimi manuel testte “evet çalışıyor, sorun yok” diye kabul etti ve çalışan aşamanın commit ile sabitlenmesini onayladı. Push yapılmadı.

## Gerçek kullanıcı, ekip ve yetki yönetimi (`840b757`)

- Kullanıcı onayıyla mevcut şefe doğrudan `manageUsers`; ekip üzerinden devredilemez.
- Şef Personel Yönetiminden gerçek kullanıcı oluşturma, aktif/pasif, geçici parola ve doğrudan yetki yönetimi yapar. Yeni/parolası yenilenen kullanıcı ilk girişte değiştirmek zorundadır.
- Yönetim uçları persisted direct izinleri yeniden doğrular; own/admin account koruması ve grant-subset sınırı merkezi policy'dedir.
- Team ve ayrı TeamMembership tabloları, DB name/member unique constraint'leri; `c9a4237b1d02` migration'ı yerel PostgreSQL'e uygulandı.
- Ekip ekranı gerçek repository'ye bağlı; archive/restore, aktiflik, üyelik reactivation ve yetkiler korunur. Teknik Ekip başlangıç kaydı üyesizdir; demo kişi hesabı yaratılmaz.
- İsim havuzu ve mühendis/ekip atama hedefleri gerçek kayıtları kullanır. Araçlar/teknik işler fake kalır; açık iş arşiv guard'ı henüz yalnız mevcut yerel adapterda garanti edilir.
- Kullanıcı ve ekip sunucu sınırı, migration, controller, adapter, mobil form ve gerçek auth navigasyon testleri eklendi.

11 Ekim 2026: gerçek auth giriş/oturum koruma/çıkış temizliği kullanıcı tarafından manuel kabul edildi. Kullanıcı/ekip ekranları için kullanıcı manuel testte “sorun yok çalışıyor” bildirdi. Dart format, Flutter analyze ve diff kontrolü temiz; 278 Flutter testi, 54 backend testi geçti. Android debug APK derlendi; gerçek PostgreSQL migration ve yerel şef kullanıcı/ekip API okumaları doğrulandı.

Bu kayıt 11 Ekim 2026 tarihinde Git geçmişi ve kod üzerinden yeniden düzenlendi. Görev numaraları teslim dilimlerini ifade eder; uygulamanın `pubspec.yaml` sürümü üretim release'i kanıtı değildir. Aşağıdaki kayıtlar commit referanslıdır; bağımsız test çalıştırma raporu değildir.

## Unreleased — Gerçek Flutter auth entegrasyonu

- Varsayılan giriş API servisine bağlandı; token/expiry için native secure storage ve web memory store eklendi.
- `/me` ile restore/doğrulama, süre dolumunda root logout, ağ/giriş hatası eşlemesi ve zorunlu parola değişimi ekranı.
- Explicit user permission alanı ve `b82d1f9c0a41` migration'ı; yerel PostgreSQL'e uygulandı.
- Gerçek UUID'yi koruyan session-user directory; demo/önceki kullanıcılar display-only, gerçek actor'ın yerine geçmez.
- Android debug yerel HTTP, release/profile HTTPS sınırı, configurable API adresi ve explicit CORS origins.
- API/controller/widget, permission migration ve backend HTTP sınırı testleri eklendi. İş/ekip/araç domain'leri hâlâ uygulama belleğindedir.

Auth diliminin yerel doğrulaması (11 Ekim 2026, `7f7cc6c` üzerindeki teslim): Dart format ve Flutter analyze temiz; o aşamada 264 Flutter testi ve 22 backend testi geçti. Android debug APK derlemesi ve PostgreSQL/API health kontrolü başarılı. Gerçek şefle giriş, oturum koruma ve çıkış temizliği daha sonra kullanıcı tarafından doğrulandı; güncel toplamlar yukarıdaki kullanıcı/ekip teslimindedir.

## Unreleased — Proje hafızası güncellemesi

- README, ROADMAP, ARCHITECTURE ve DECISIONS mevcut kodla uyumlu hale getirildi.
- Eski Firebase planı ile güncel FastAPI/PostgreSQL yönü ayrıldı.
- Flutter'ın fake auth/repository kullandığı, backend bağlantısının henüz yapılmadığı kaydedildi.
- Tamamlanan dikey dilimler, açık güvenlik/kalıcılık başlıkları ve önerilen devam sırası belgelendi.
- Eski ilerleme yüzdeleri ve güncel test sonucu gibi görünen tarih/referanssız iddialar kaldırıldı.

Bu dokümantasyon tesliminde uygulama kodu değiştirilmedi; Flutter/backend testleri yeniden çalıştırılmadı.

## Backend — Güvenli kimlik doğrulama (`7f7cc6c`)

- Giriş, mevcut kullanıcı ve parola değiştirme HTTP uçları.
- Süreli JWT erişim tokenı, aktif kullanıcı dependency'si ve zorunlu parola değişimi sınırı.
- Parola politikası ve auth servis testleri.
- Flutter'ın backend'e bağlanması bu teslimin parçası değildir.

## Backend — Temel kurulum (`45c352d`)

- FastAPI uygulaması, health uçları ve environment ayarları.
- PostgreSQL/SQLAlchemy altyapısı, User modeli ve Alembic migration.
- Argon2 parola hash'i ve etkileşimli ilk şef oluşturma aracı.
- Bootstrap ve güvenlik testleri.

## Araç modülü

| Commit | Referans | Kapsam |
| --- | --- | --- |
| `b5f7a3b` | TCK-VEHICLE-008 | Arıza değerlendirme akışı. |
| `2d8ec1b` | TCK-VEHICLE-007 | Arıza ve bakım kayıtları. |
| `6103933` | TCK-VEHICLE-006 | Teslim ve kontrol akışı. |
| `f66e40e` | TCK-VEHICLE-005 | Personel ataması ve atama geçmişi. |
| `02d0e99` | TCK-VEHICLE-004 | Araç düzenleme ve durum yönetimi. |
| `ab7c87d` | TCK-VEHICLE-003 | Güvenli araç kayıt/ekleme. |
| `f15dd39` | TCK-VEHICLE-002 | Responsive araç detay ekranı. |
| `f6d3f81` | TCK-VEHICLE-001 | Araç domain/repository/controller, filo sayfası, arama/filtre/sayaçlar. |

Araç verisi paylaşılan fake repository'de tutulur; kalıcı araç backend'i henüz yoktur.

## Teknik operasyonlar, ekipler ve navigasyon

| Commit | Referans | Kapsam |
| --- | --- | --- |
| `079411a` | TCK-TECH-011 | Eşzamanlı ilerleme gönderimi koruması düzeltmesi. |
| `e9342e9` | TCK-NAV-001 | Şef modül ana sayfası, gerçek navigasyon ve logout route temizliği. |
| `969cd04` | TCK-TECH-010 | Güvenli beklemeye alma/devam ve döngü geçmişi. |
| `1e699d6` | TCK-TECH-009 | Tamamlama talebi, onay kuyruğu ve onay/red geçmişi. |
| `0e13679` | TCK-TECH-008 | Yetkili detay okuma ve ilerleme notları. |
| `279edfe` | TCK-TECH-007 | Aktif ekip üyesine iş görünürlüğü, güvenli başlatma ve operasyon metadata'sı. |
| `02bf2cc` | TCK-TEAM-001 | Ekip/üyelik/yetki, archive/restore, isim invariantları ve güvenlik policy'si. |
| `2ec33ec` | TCK-TECH-006 | Şefin inceleme, öncelik ve kullanıcı/ekip ataması. |
| `5428435` | TCK-TECH-005 | Rol bazlı saha bildirimi oluşturma akışı. |
| `90f6f57` | TCK-TECH-004 | Saha bildirimi controller'ı. |
| `53bd63b` | TCK-TECH-003 | Saha bildirimi repository desteği. |
| `975c87a` | TCK-AUTH-004 | Responsive şef operasyon dashboard'u. |

## İlk proje temeli

9 Temmuz 2026 tarihli önceki belgelerde kaydedilen başlangıç:

- Flutter proje kurulumu ve feature-first mimari.
- Tema/tokenlar, responsive dashboard ve ortak `AppCard` dahil UI bileşenleri.
- Widget testleri ve proje belgeleri.
- Firebase başlangıç planı; mevcut backend yönü daha sonra FastAPI/PostgreSQL oldu.

## Kayıt kuralı

Her yeni teslimde kapsam, commit/görev referansı, önemli düzeltmeler ve gerçek doğrulama sonuçları eklenir. Test sayıları yalnız çalıştırıldıkları taban ve tarih ile kaydedilir. Tamamlanmamış backend bağlantıları veya planlanan özellikler teslim edilmiş gibi yazılmaz.
