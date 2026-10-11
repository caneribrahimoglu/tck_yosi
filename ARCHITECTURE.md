# TCK YÖSİ — Mevcut mimari

11 Ekim 2026 tarihinde `7f7cc6c` tabanı incelenerek güncellendi.

## İki ayrı çalışma katmanı

```text
Flutter auth UI → AuthController → SessionAuthService → ApiAuthService → FastAPI
Flutter iş UI → ChangeNotifier controller → domain port/repository → fake adapter

FastAPI route → dependency/service → SQLAlchemy session/model → PostgreSQL
```

Flutter auth, kullanıcı yönetimi ve ekip repository'si backend'e bağlıdır. İş/araç verisi henüz backend'e kaydedilmez. Domain arayüzleri korunur; testlerde fake repository'ler injection ile kullanılmaya devam eder.

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
  app/models/                 User, Team, TeamMembership ve permission enum
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

Teknik işler fake kalırken açık iş arşivleme kontrolü yerel `TechnicalWorkTeamArchiveGuard` ile yapılır. Backend henüz teknik iş tablosu bilmediğinden bu, cihazlar arası sunucu garantisi değildir; kalıcı iş migration'ı ve sunucu transaction guard sonraki teknik operasyon diliminde birlikte eklenmelidir.

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
- Fake repository'lerde eşzamanlı submission/karar için in-flight korumaları ve yeniden doğrulama bulunur. Backend'e geçişte bunların transaction/constraint karşılığı gerekir.

Teknik işlerin mevcut geniş liste okuma API'leri, detay okumaya getirilen actor sınırıyla aynı ölçüde ele alınmış değildir. Bu önceden kalan borç, backend listelerinin yetkilendirme tasarımında kapatılmalıdır.

## Ekip ve araç kuralları

Ekip üyelikleri ayrı kayıtlardır; kullanıcı birden fazla ekibe katılabilir. Adlar trim/case-insensitive benzersizlikle kontrol edilir. Arşivli ekip mutable değildir; tek dönüş geri yüklemedir. Restore kimlik/üyelik/yetkileri korur, ekibi pasif yapar. Merkezi `TeamPermissionPolicy`, ekip yönetimi ve grant edilebilir yetkileri sınırlar.

Araç domain'i kuruma ait/sözleşmeli ayrımı, tür, kilometre ve operasyon durumunu taşır. Sözleşmeli araçta yüklenici zorunludur. Atama, kullanım/teslim, kontrol, arıza/bakım ve arıza değerlendirme kayıtları ayrı domain modelleridir. Görünen sayaçlar ve filtreler controller state'inden türetilir.

## Backend sınırı

Kalıcı modeller `User`, `Team` ve `TeamMembership`'tir. Kullanıcı direct permission'ları ve ekip izinleri ayrı JSON listelerinde; üyelikler ayrı kayıtlarla saklanır. Araç/teknik iş tabloları henüz yoktur. UserResponse'daki permission enum değerleri Flutter AppPermission sözleşmesiyle eşleşir; role bakarak yetki üretilmez.

- Parolalar Argon2 ile hash'lenir; yeni parola minimum 12 karakterdir.
- JWT erişim tokenı HS256 ile imzalanır; örnek ayarda ömür 30 dakikadır.
- Auth dependency tokenı doğrular ve kullanıcıyı veritabanından yeniden okur; eksik/pasif actor reddedilir.
- Zorunlu parola değişimi dependency'si bütün yeni kullanıcı/ekip uçlarında uygulanır; gelecekteki iş endpoint'leri de bu sınırı kullanmalıdır.
- Health/auth, kullanıcı yönetimi ve ekip/üyelik/yetki uçları vardır. Refresh token, revocation/logout ve iş/araç API'leri henüz yoktur.
- Ayarlar environment/`.env` üzerinden alınır; gerçek secret değerleri source control'e yazılmaz.
- API adresi `API_BASE_URL` dart-define ile seçilir. Yerel HTTP yalnız Flutter debug'da kabul edilir; release/profile HTTPS ister. CORS yalnız açıkça yapılandırılmış origin'lere izin verir.

## Geliştirme ilkeleri

İş kuralı widget'a gömülmez. UI görünürlüğü güvenlik yerine geçmez. Korunan yönetim yetkileri ekip grant listesine gelişigüzel eklenmez. Yeni dilimler mevcut port/controller/UI kitini kullanır; gereksiz paket ve geniş refactor eklenmez. Güvenlik, durum geçişi, concurrency ve navigasyon testleri ilgili sınırda yazılır.
