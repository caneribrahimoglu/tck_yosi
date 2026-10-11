# TCK YÖSİ

Karayolu işletme şefliği için geliştirilen Flutter tabanlı operasyon ve yönetim platformu. Teknik işler, ekipler ve araçlar aynı uygulama içinde, kullanıcıların rol ve yetkilerine göre yönetilir.

## Güncel durum

Bu belge 11 Ekim 2026 tarihinde güncellendi. `840b757` gerçek auth/kullanıcı/ekip teslimi üzerine ilk teknik operasyon backend dilimi eklendi. Önceki auth/kullanıcı/ekip akışları ve yeni iş dilimi kullanıcı tarafından manuel doğrulandı.

| Alan | Mevcut durum |
| --- | --- |
| Flutter uygulaması | Responsive Violet UI, rol bazlı dashboardlar ve şef modül ana sayfası mevcut. |
| Teknik operasyonlar | Bildirim, yetkili liste/detay ve mühendis/ekip ataması gerçek API/DB'ye bağlı. Başlatma/ilerleme/bekleme/onay henüz yalnız izole fake/test uygulamasında mevcut. |
| Ekipler | Üyelik, yetki, aktif/pasif, arşiv/geri yükleme gerçek PostgreSQL kayıtlarına bağlı. |
| Araçlar | Filo, detay, ekleme/düzenleme, atama geçmişi, teslim/kontrol, arıza ve bakım akışları mevcut. |
| Personel | Şef için gerçek kullanıcı oluşturma, aktiflik, geçici parola ve doğrudan yetki yönetimi. Mesai/izin gibi personel süreçleri henüz yok. |
| Backend | FastAPI, PostgreSQL/SQLAlchemy, Alembic ve güvenli kimlik doğrulama temeli mevcut. |
| Flutter–backend bağlantısı | Auth, kullanıcılar, ekip/üyelik/yetkiler ve teknik bildirim/atama gerçek API'ye bağlı. Araçlar demo. |

Kullanıcılar, ekipler, teknik işler ve atama geçmişi PostgreSQL'de kalıcıdır; çıkış/giriş veya uygulama yeniden açılışı kayıtları sıfırlamaz. Araç fake verisi yeniden başlatılınca sıfırlanır. Gerçek kullanıcı UUID'si demo ID'sine çevrilmez. Eski fake teknik işler veritabanına aktarılmaz; ilk gerçek iş listesi boş başlayabilir. Gerçek işlerde desteklenmeyen lifecycle işlemleri fake repository'ye yönlendirilmez.

## Çalışan ürün akışları

- Şef girişte Şeflik Ana Sayfasını görür; Operasyon Merkezi, Araç Yönetimi ve yetkisi varsa Personel Yönetimine geçer.
- Saha bildirimi şef tarafından incelenir, önceliklendirilir ve kullanıcıya veya ekibe atanır.
- Aktif doğrudan atanan mühendis veya aktif/arşivlenmemiş ekibin aktif üyesi atanmış işi listede ve detayda görür. Oluşturan kendi bildirimini, explicit `viewAllTechnicalWork` sahibi tüm işleri okuyabilir.
- Gerçek iş detayında başlık/açıklama/konum, öncelik/durum ve çözümlenmiş kişi/ekip isimleri bulunur. Başlatma, ilerleme, bekleme/devam ve tamamlama onayı sonraki backend dilimlerine bırakıldı; gerçek ekranda hazırlık bilgisi gösterilir.
- Ekipler silinmez; arşivlenir. Geri yüklenen ekip aynı kimlik/üyelik/yetkilerle pasif olarak döner.
- Şef Personel Yönetiminden kullanıcı oluşturur; yeni kullanıcı ilk girişte en az 12 karakterlik yeni parola belirler. Şef kullanıcının aktifliğini, geçici parolasını ve sahip olduğu yetkiler sınırında doğrudan izinlerini yönetir.
- Şefin `manageUsers` yetkisi doğrudandır; ekipten devredilemez. Bu ekran kendi şef hesabını veya diğer yönetici hesaplarını değiştirmez, yönetici rolü oluşturmaz.
- Araçlarda kurum/sözleşmeli ayrımı, filtreleme, yönetim, personel ataması, teslim/kontrol ve arıza/bakım geçmişi bulunur.

## Teknoloji ve çalışma yapısı

- İstemci: Flutter/Dart; feature-first yapı, repository arayüzleri ve `ChangeNotifier` controller'lar.
- Sunucu: FastAPI, SQLAlchemy, PostgreSQL, Alembic.
- Backend kimlik doğrulama: Argon2 parola hash'i ve süreli JWT erişim tokenı.
- Ortak UI: `lib/core/theme`, tasarım tokenları ve `lib/shared/widgets`.
- Android, iOS, Windows, macOS, Linux ve web için Flutter platform klasörleri bulunur. Bu, tüm platformların üretim ortamında doğrulandığı anlamına gelmez.

Firebase eski planın parçasıydı; mevcut kodda Firebase entegrasyonu yoktur. Güncel backend yönü FastAPI/PostgreSQL'dir.

## Yerelde çalıştırma

Flutter proje kökünde:

```powershell
flutter pub get
flutter run
```

Uygulama artık gerçek backend hesabı/parolası ister. `FakeAuthService` içindeki `123456` demo parolaları yalnız izole test/demo servis verisidir; gerçek girişte kullanılmaz. Mevcut yerel backend hesabının kullanıcı adı `sef`'tir; gerçek parola belgelenmez.

Debug'da varsayılan API adresi Android emülatöründe `http://10.0.2.2:8000/api/v1/`, masaüstünde `http://127.0.0.1:8000/api/v1/` olur. Fiziksel cihaz veya farklı sunucu için adresi açıkça verin:

```powershell
flutter run --dart-define=API_BASE_URL=https://SUNUCU_ADRESI/api/v1/
```

Release/profile için HTTPS adresi zorunludur. Android'in cleartext izni yalnız debug manifestinde açıktır. Yerel HTTP kullanımını üretim kurulumu saymayın.

Backend komutlarını `backend` dizininde çalıştırın:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
```

`.env` içindeki PostgreSQL bağlantısını ve `SECRET_KEY` değerini yerel ortama göre düzenleyin. Örnek `CHANGE_ME` değerleriyle gerçek ortam kurmayın. PostgreSQL veritabanı/kullanıcısı ayrıca hazırlanmalıdır; bu komutlar veritabanı sunucusu oluşturmaz. `.env` ve gerçek parolalar Git'e eklenmemelidir.

```powershell
alembic upgrade head
python -m app.cli.create_initial_chief
python -m uvicorn app.main:app --reload
```

İlk şef oluşturma aracı yalnız boş kullanıcı tablosunda çalışır; parolayı gizli ve etkileşimli alır. Hesap `must_change_password` işareti ve kayıtlı explicit yetkilerle oluşturulur. Flutter ilk girişte yeni parola belirlenmeden dashboard'a geçirmez. Parola en az 12 karakter olmalıdır.

Yeni `b82d1f9c0a41` migration'ı kullanıcıya JSON `permissions` alanı ekler ve önceki bootstrap hesabı olan en eski şefe explicit başlangıç yetkilerini yazar; diğer hesaplar boş yetki listesiyle kalır. Bu migration yerel geliştirme veritabanına uygulanmıştır. Başka ortamda önce `alembic upgrade head` çalıştırılmalıdır.

`c9a4237b1d02` migration'ı ekip ve ayrı üyelik tablolarını kurar, en eski bootstrap şefe `manageUsers` ekler ve üyesiz bir gerçek “Teknik Ekip” oluşturur. Hayali Zeynep/Ahmet hesapları veritabanına aktarılmaz; kullanıcıları şef oluşturur ve ekiplere ekler. Ekip adı Türkçe trim/case normalizasyonuyla, üyelik ekip/kullanıcı çiftiyle veritabanında benzersizdir. Üye çıkarma üyeliği pasifleştirir; yeniden ekleme aynı üyelik ID'sini korur.

`d1b9e206f734` migration'ı gerçek teknik iş ve ayrı atama geçmişi tablolarını kurar; yerel PostgreSQL'e uygulandı. Bildirimde kimlik/zaman/oluşturan/durum sunucudan gelir. Aynı gönderim anahtarının tekrarında aynı kayıt döner. Atama revision kontrolü eski ekranın yeni atamayı ezmesini engeller; geçmiş silinmez. Açık işi bulunan ekip artık sunucu transaction sınırında arşivlenemez.

Android/masaüstü oturum tokenı `flutter_secure_storage` ile saklanır; parola veya güvenilen kullanıcı/yetki kopyası saklanmaz. Açılışta `/me` ile yeniden doğrulanır. Web'de bearer token kalıcı web storage yerine yalnız bellekte tutulur; sayfa yenilenince yeniden giriş gerekir. Web geliştirme için backend `.env` dosyasında `CORS_ORIGINS=["http://localhost:5173"]` ayarlayıp `flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1/` kullanın; `.env` değişince backend'i yeniden başlatın.

Token süresi dolduğunda, `/me` 401/403 veya iş uçları 401 verdiğinde oturum ve child route'lar kapatılır. Yönetim uçlarındaki 403 yetki reddi oturumu gereksiz yere kapatmaz. Çıkış tokenı istemciden temizler; backend revocation/refresh token henüz yoktur.

Mevcut backend uçları:

- `GET /health`
- `GET /health/database`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `POST /api/v1/auth/change-password`
- `GET /api/v1/directory` (oturumlu isim/rol havuzu; doğrudan izin/parola bilgisi yok)
- `GET|POST /api/v1/users`; `POST /users/{id}/active|permissions|reset-password`
- `GET|POST /api/v1/teams`; `GET /teams/memberships|effective-permissions`
- `POST /teams/{id}/details|active|archive|restore|permissions|members`
- `POST /teams/{id}/members/{userId}/remove`
- `GET|POST /api/v1/technical-works`; `GET /technical-works?assigned_only=true`
- `GET /technical-works/assignment-targets`
- `GET /technical-works/{id}`; `GET /technical-works/{id}/assignments`
- `POST /technical-works/{id}/assign` (priority, tek hedef ve expected_revision)

Teknik lifecycle (başlatma/ilerleme/bekleme/tamamlama), araç API'leri, refresh token ve sunucu tarafı token iptali henüz uygulanmadı. Atama hedefleri güncel DB kullanıcı/ekiplerinden gelir. Şef çapında atama, doğrudan `assignTechnicalWork` + `viewAllTechnicalWork` izinlerini gerektirir; yalnız rol veya istemcinin gönderdiği kullanıcı/yetki bilgisi yeterli değildir.

## Kalite kontrolleri

Flutter proje kökünde:

```powershell
dart format lib test
flutter analyze
flutter test
git diff --check
```

Backend ortamı ve `.env` hazırken, `backend` dizininde:

```powershell
python -m pytest
```

Yerel PostgreSQL hazırsa gerçek yarış testlerini de çalıştırın (yalnız üretilen geçici test şeması kullanılır; uygulama verisi değiştirilmez):

```powershell
$env:TCK_TEST_POSTGRES = '1'
python -m pytest
Remove-Item Env:TCK_TEST_POSTGRES
```

Yeni dilim manuel QA: şefle Operasyon Merkezi'nde bildirim oluşturun, gerçek aktif mühendis/ekibe öncelikle atayın; ekibe atıyorsanız mühendisi aktif üye yapın. Çıkış yapıp mühendisle girin, listeden detayı açın ve isim/konumu doğrulayın. Uygulamayı kapatıp açınca kayıt korunmalı. Şimdilik “İşi Başlat” görünmemesi beklenen davranıştır. Açık işe atanmış ekibi arşivleme reddedilmelidir.

Testler repository kuralları, controller durumları, widget/navigasyon, API auth adapterı, migration ve backend HTTP/güvenlik sınırlarını kapsar. Teslimin gerçek doğrulama sonuçları CHANGELOG'da tutulur.

## Proje hafızası

- [ROADMAP.md](ROADMAP.md): tamamlanan dilimler, eksikler ve önerilen devam sırası.
- [ARCHITECTURE.md](ARCHITECTURE.md): mevcut katmanlar, composition ve güvenlik sınırları.
- [DECISIONS.md](DECISIONS.md): mimari kararlar ve eski kararların güncel durumu.
- [CHANGELOG.md](CHANGELOG.md): commitlerle ilişkilendirilmiş gelişim kaydı.

Yeni bir oturumda önce Git durumu ve son commit incelenmeli, bu belgelerdeki referansla karşılaştırılmalı ve ilgili testler çalıştırılmalıdır. Projenin ilerleme yüzdesi veya üretime hazır olduğu varsayılmamalıdır.
