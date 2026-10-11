# TCK YÖSİ — Mevcut mimari

11 Ekim 2026: `31c2d45` tabanı üzerindeki ikinci teknik backend dilimine göre güncellendi. İlk dilimin manuel kabulü tamamlandı; yürütme diliminin cihaz üstü kabulü bekleniyor.

## İki ayrı çalışma katmanı

```text
Flutter auth UI → AuthController → SessionAuthService → ApiAuthService → FastAPI
Flutter teknik iş UI → ChangeNotifier controller → domain repository → API adapter → FastAPI
Flutter araç UI → ChangeNotifier controller → domain repository → fake adapter

FastAPI route → dependency/service → SQLAlchemy session/model → PostgreSQL
```

Auth, kullanıcılar, ekipler ve teknik bildirim/atama/başlatma/ilerleme/bekleme-devam backend'e bağlıdır; araçlar fake adapter kullanır. Domain arayüzleri korunur; izole fake testlerde tam teknik lifecycle çalışmaya devam eder. Gerçek adapterda `supportsExecution=true`, `supportsCompletion=false`: yalnız sunucuda karşılığı bulunan aksiyonlar açılır, tamamlama/onay ekranları kapalıdır ve fake write fallback yoktur.

## Dizinler ve sorumluluklar

```text
lib/
  app/                        composition root ve uygulama kurulumu
  core/                       tema, token, enum ve responsive yardımcıları
  shared/widgets/             ortak Violet UI bileşenleri
  features/
    auth/                     kullanıcı, rol, permission, auth controller/gate
    dashboard/                rol resolver'ı, şef ana sayfası ve operasyon ekranı
    technical_operations/     teknik iş lifecycle ve geçmişleri
    teams/                    ekip, üyelik, yetki ve feature adapterları
    vehicles/                 filo, araç geçmişi ve araç operasyonları
    personnel/                modül hazırlık sayfası
    users/                    kullanıcı yönetimi repository/controller/UI

backend/
  app/api/                    route ve auth dependencies
  app/core/                   ayarlar ve parola/JWT güvenliği
  app/db/                     engine, session, declarative base
  app/models/                 User, Team/Membership, TechnicalWork/Assignment/ProgressNote/HoldRecord
  app/schemas/                HTTP giriş/çıkış modelleri
  app/services/               auth ve ilk kullanıcı iş kuralları
  app/cli/                    etkileşimli ilk şef oluşturma aracı
  migrations/                 Alembic migration'ları
  tests/                      backend servis/güvenlik testleri
```

Feature'larda domain/data/presentation ayrımı uygulanır. Eski dashboard gibi yerlerde mevcut `pages/widgets` düzeni korunur; tek tip klasör görünümü için geniş refactor yapılmaz.

## Flutter composition ve yaşam döngüsü

`lib/app/app.dart`, auth servisini, paylaşılan repository'leri ve controller'ları kurar. Controller'ları sahiplenen uygulama root'u `dispose` eder. Sayfalar repository/controller kopyaları üretmez; bağımlılıkları injection ile alır.

`AuthGate`, oturum durumuna göre login veya rol dashboard'unu gösterir. `RoleDashboardResolver` ilgili dashboardu seçer; şef için `ChiefHomePage` açılır. Şef ana sayfasından operasyon, araç ve personel child modülleri açılır. AuthGate, unauthenticated durumunu dinler ve frame sonunda root Navigator'ı ilk route'a kadar geri alır. Böylece LoginPage görünür olur; eski child ekran yeni kullanıcı oturumuna taşınmaz.

Paylaşılan fake repository'ler sayesinde uygulama kapanmadığı sürece çıkış/giriş geçmiş kayıtları silmez. Bu yaşam döngüsü, kalıcı storage veya güvenli backend oturumu yerine geçmez.

`ApiAuthService` HTTP client, timeout, typed hata ve session-store portunu sahiplenir. Android/masaüstünde secure storage, web'de bellek içi store kullanılır. Saklanan veri yalnız token/expiry'dir; restore `/me` ister. HTTP redirect'leri takip edilmez. AuthController süre dolumunda oturumu bitirir; `/me` 401/403 de aynı root cleanup yolunu tetikler. `mustChangePassword` dashboard yerine parola ekranı açar. Hatalı/ağdan dönmeyen girişte demo servise otomatik fallback yoktur.

`ApiUserDirectory`, gerçek isim/rol havuzunu `/directory` üzerinden okur; mevcut actor `/me` ile yeniden doğrulanır. Başka hesaplar erişim actor'ı olarak değil, isim kaynağı olarak dönür. Eski demo operasyon kullanıcı ID'leri için yalnız inactive/yetkisiz isim fallback'i tutulur; gerçek kullanıcı/atama havuzuna girmez. Fake auth enjekte edilen testler için önceki directory köprüsü korunur.

`ApiTeamRepository` ve `ApiUserManagementRepository`, `ApiAuthService.requestBusiness` üzerinden aynı bearer oturumunu kullanır. İstemci `actorPermissions` sunucuya gönderilmez; sunucu current user ve direct grants'i DB'den yükler. Stale bir oturumun geç dönen yanıtı yeni oturuma veri taşıyamaz. User controller da actor-generation kontrolüyle eski listeyi temizler.

Backend yönetim policy'si mutasyondan önce aktiflik, parola değişimi ve doğrudan yönetim izni ister. Transaction'da actor/target row lock'ları, DB'de normalize ekip adı ve üyelik çifti unique constraint'leri bulunur. Team permission grant'leri şefin kendi direct grant listesiyle sınırlı ve korunan sistem izinlerinden arındırılmıştır. Korunan izinler legacy ekip verisinde bulunsa bile effective-permissions hesabına katılmaz.

Kullanıcı yönetimi kendi/diğer yönetici hesabını değiştirmez, yönetici rolü oluşturmaz; operational hesaplar boş direct grants ve zorunlu geçici parola değişimiyle açılır. Şefin `manageUsers` yetkisi explicit migration/bootstrap grant'idir; role fallback yoktur. Üyelik kaldırma pasifleştirir, yeniden ekleme aynı ID'yi korur. Ekip restore aynı ID/izin/üyelikle pasif döner.

`ApiTechnicalWorkRepository` aynı authenticated transport'u kullanır. İş verisi JWT actor'ına göre filtrelenir; istemci creator ID veya grant göndermeyle otorite kuramaz. Controller paralel yüklemeleri Future.wait ile toplar; oturum temizliğinde iş state'i ve isimler sıfırlanır, geç yanıt yeni kullanıcıya taşınmaz. İsimler mevcut kullanıcı/ekip portlarından çözülür; domain storage'da isim yoktur.

`d1b9e206f734` migration'ı iş ve append-only atama geçmişini kurar. Bildirim idempotency anahtarı actor/submission çiftiyle DB'de benzersizdir. Actor row lock ve yeniden doğrulama sonrası aynı payload aynı kaydı döndürür; farklı payload conflict verir. Form aynı gönderimin timeout sonrası tekrarında aynı request/key'i kullanır (uygulama yeniden başlatması sonrası taslak/key kalıcılığı henüz yok).

Şef çapında atama direct `assignTechnicalWork` ve `viewAllTechnicalWork` ister. Güncel aktif mühendis veya aktif/arşivlenmemiş ekip hedefi kilitlenir, iş row lock altında revision/state tekrar kontrol edilir. Dialog açıldığı andaki revision gönderilir; stale conflict güncel listeyi yükler, yeni atamayı sessizce ezmez. Aynı anda kullanıcı+ekip hedefi DB constraint'iyle de yasaktır. Ekip arşivleme aynı team row lock üzerinden açık işleri kontrol eder; yerel guard yalnız erken UX kontrolüdür, sunucu nihai otoritedir. Bu yarışlar izole PostgreSQL şeması testlerinde doğrulandı.

Yürütme mutasyonları `technical_work_execution` servisindedir. Önce current actor/assignment/permission doğrulanır; sonra actor → sıralı etkin ekipler → iş kilitleri altında yeniden doğrulanır. Global okuma mutasyon hakkı vermez; yetkisiz/missing işe aynı güvenli 403 döner, durum bilgisi açılmaz. Kilit alındıktan sonra eklenen bir üyelikten gelen kilitlenmemiş izin bu işlemde kullanılmaz. Başlatma/bekleme/devam revision artırır; bekleme/devam aynı captured revision ile iki defa veya ters yönde yarışarak uygulanamaz.

`e8a7152c4906` migration'ı ayrı progress/hold tablolarını kurar. İlerleme work/actor/submission unique anahtarıyla tekrar gönderimde tek not üretir; client aynı içerikte başarısız gönderimi aynı request/key ile tekrarlar. Bir işte tek açık bekleme döngüsü partial unique index ile korunur. Resume yalnız açık döngünün resume alanlarını tamamlar; eski döngüyü değiştirmez, sonraki hold yeni kayıt oluşturur. Flutter history listeleri immutable'dır. Detail ve hold controller'ları logout/dispose/generation ile geç yanıtı atar; mutation sonrası detay/capability/history ve dönüşte dashboard yeniden yüklenir.

## Domain ve feature sınırları

- Modeller immutable değerlerdir; UI isimleri domain kayıtlarına yazılmaz.
- Controller, yükleme/gönderme/hata durumunu ve presentation state'ini yönetir.
- Repository, kaynak veriden yetkiyi ve durum geçişini doğrular; sistem ID/zaman alanlarını üretir ve geçmişi korur.
- Teknik operasyon domain'i teams implementasyonuna doğrudan bağlanmaz. Ekip hedefi, actor erişimi ve isim çözümleme için port/adaptor kullanılır.
- `TeamAssignmentTargetAdapter`, `TeamTechnicalWorkAccessAdapter` ve `TechnicalWorkParticipantNameAdapter`, paylaşılan ekip/kullanıcı kaynaklarını bu portlara bağlar.
- `TechnicalWorkTeamArchiveGuard`, açık teknik işi olan ekip arşivleme sınırını composition üzerinden kurar.
- Role, doğrudan kullanıcı permission'ı ve ekip üyeliği/yetkisi ayrı kavramlardır; `AppUser.teamIds` üyelik source of truth'u değildir.
- Etkin yetki, doğrudan yetkiler ve aktif üyelikle bağlı aktif/arşivlenmemiş ekip yetkilerinin birleşimidir. Explicit deny sistemi yoktur.

## Teknik iş kuralları

Aşağıdaki tam lifecycle kuralları fake/test implementasyonunda mevcut ürün tasarımıdır. Gerçek backend bildirim → atama → başlatma, ilerleme ve bekleme/devam ile yetkili okuma/audit'i uygular. Tamamlama talebi/onay/red henüz sonraki dilime aittir.

- Temel akış: bildirim/inceleme → atama → `inProgress` → `awaitingCompletionApproval` → `completed`.
- Tamamlama reddi işi `inProgress` durumuna döndürür; talep geçmişi korunur.
- `inProgress` → `onHold` için gerekçe gerekir; devam `onHold` → `inProgress` geçişidir.
- Beklemede ilerleme notu ve tamamlama talebi repository sınırında engellenir.
- Başlatma ekip atamasını değiştirmez; `startedByUserId` ve `startedAt` ayrı saklanır.
- İlerleme notları, tamamlama talepleri ve bekleme döngüleri ayrı immutable geçmiş kayıtlarıdır.
- Mutasyon için aktif actor, uygun assignment/aktif ekip üyeliği ve ilgili explicit permission gerekir.
- Detay/history okuma da actor ister. Global okuma `viewAllTechnicalWork` ile sağlanır; rol adı tek başına yetki değildir.
- Tamamlama inceleme doğrudan `reviewTechnicalWorkCompletion` gerektirir; ekipten devredilemez.
- Authorization durum hatalarından önce yapılır; typed hatalar controller'da güvenli kullanıcı mesajlarına çevrilir.
- Fake repository'lerde in-flight korumaları vardır. Mevcut backend yürütme geçişleri row lock/revision, notlar idempotency ve açık bekleme döngüsü unique constraint ile korunur; tamamlama kararının backend karşılığı henüz yoktur.

Gerçek liste/detay/audit okumalarında aynı kapsam filtresi vardır: current active actor, kendi oluşturduğu bildirim veya doğrudan assignment veya aktif/arşivlenmemiş ekipte aktif üyelik; explicit direct `viewAllTechnicalWork` tüm kayıtları açar. Eksik/inaccessible UUID aynı typed 403 verir. Assigned-only listede ekip yoluyla yalnız açık işler gelir; OR sorgusu aynı işi tek kayıt getirir. Eski fake geniş liste API'sinin borcu gerçek sunucuya aktarılmadı.

## Ekip ve araç kuralları

Ekip üyelikleri ayrı kayıtlardır; kullanıcı birden fazla ekibe katılabilir. Adlar trim/case-insensitive benzersizlikle kontrol edilir. Arşivli ekip mutable değildir; tek dönüş geri yüklemedir. Restore kimlik/üyelik/yetkileri korur, ekibi pasif yapar. Merkezi `TeamPermissionPolicy`, ekip yönetimi ve grant edilebilir yetkileri sınırlar.

Araç domain'i kuruma ait/sözleşmeli ayrımı, tür, kilometre ve operasyon durumunu taşır. Sözleşmeli araçta yüklenici zorunludur. Atama, kullanım/teslim, kontrol, arıza/bakım ve arıza değerlendirme kayıtları ayrı domain modelleridir. Görünen sayaçlar ve filtreler controller state'inden türetilir.

## Backend sınırı

Kalıcı modeller User, Team, TeamMembership, TechnicalWork, TechnicalWorkAssignment, TechnicalWorkProgressNote ve TechnicalWorkHoldRecord'dır. Araç ve completion history tabloları henüz yoktur. Kullanıcı direct izinleri ve ekip izinleri ayrı JSON alanlarında, üyelikler ayrı tablodadır. Permission enum'ları Flutter sözleşmesiyle eşleşir; rol runtime grant üretmez.

- Parolalar Argon2 ile hash'lenir; yeni parola minimum 12 karakterdir.
- JWT erişim tokenı HS256 ile imzalanır; örnek ayarda ömür 30 dakikadır.
- Auth dependency tokenı doğrular ve kullanıcıyı veritabanından yeniden okur; eksik/pasif actor reddedilir.
- Zorunlu parola değişimi dependency'si kullanıcı/ekip ve bütün teknik iş uçlarında uygulanır.
- Health/auth, kullanıcı/ekip ve teknik bildirim/liste/detay/atama/audit/başlatma/ilerleme/bekleme-devam uçları vardır. Refresh/revocation, teknik tamamlama/onay ve araç API'leri henüz yoktur.
- Ayarlar environment/`.env` üzerinden alınır; gerçek secret değerleri source control'e yazılmaz.
- API adresi `API_BASE_URL` dart-define ile seçilir. Yerel HTTP yalnız Flutter debug'da kabul edilir; release/profile HTTPS ister. CORS yalnız açıkça yapılandırılmış origin'lere izin verir.

## Geliştirme ilkeleri

İş kuralı widget'a gömülmez. UI görünürlüğü güvenlik yerine geçmez. Korunan yönetim yetkileri ekip grant listesine gelişigüzel eklenmez. Yeni dilimler mevcut port/controller/UI kitini kullanır; gereksiz paket ve geniş refactor eklenmez. Güvenlik, durum geçişi, concurrency ve navigasyon testleri ilgili sınırda yazılır.
