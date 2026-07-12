# Changelog

All notable changes to **TCK YÖSİ** will be documented in this file.

This project follows a chronological changelog format.

---
# Changelog

Tüm önemli değişiklikler bu dosyada tutulur.

Bu proje, Semantic Versioning mantığına benzer şekilde geliştirme oturumları baz alınarak kayıt altına alınmaktadır.

---

## Unreleased

### Added

- Design System için `AppCard` ortak bileşeni oluşturuldu.
- `AppCard` içerisine standart:
    - Border Radius
    - Padding
    - Shadow
    - Ripple Effect
    - Material Surface
      yapısı eklendi.
- Dashboard kartları `AppCard` kullanacak şekilde refactor edildi.

### Changed

- Dashboard içerisindeki magic number'lar kaldırıldı.
- Padding değerleri `AppSpacing` üzerinden yönetilmeye başlandı.
- Radius değerleri `AppRadius` üzerinden yönetilmeye başlandı.
- Ortak tasarım tokenlarının kullanım oranı artırıldı.

### Fixed

- Widget testi yeni uygulama mimarisine göre güncellendi.
- `flutter analyze` temiz hale getirildi.
- `flutter test` başarıyla çalışır duruma getirildi.

# [Unreleased]

## Added

* Project documentation improvements
* Planned Flutter lessons
* Future module planning

---

# [0.1.0] - 2026-07-09

## Initial Project Setup

### Added

* Flutter project created
* Android Studio configured
* Project successfully running
* First emulator test completed

### Architecture

* Feature First Architecture selected
* Folder structure created
* Shared module structure established
* Repository pattern planned

### Documentation

* README.md created
* ARCHITECTURE.md created
* ROADMAP.md created
* CHANGELOG.md created

### Flutter Foundation

Created:

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── router.dart
```

Created Dashboard module

```text
features/
└── dashboard/
    ├── models/
    ├── pages/
    ├── repositories/
    └── widgets/
```

Created additional feature modules

* Authentication
* Directorates
* Departments
* Vehicles
* Drivers
* Personnel
* Assignments
* Reports

### Learning

Studied

* Flutter project structure
* main()
* runApp()
* MaterialApp
* Scaffold
* StatelessWidget
* Widget basics
* Feature First Architecture
* Single Responsibility Principle

### Current Status

Application flow

```text
main.dart

↓

runApp()

↓

TckYosiApp

↓

MaterialApp

↓

DashboardPage

↓

Scaffold
```

Application launches successfully.

---

# Version History

| Version | Status     | Description                |
| ------- | ---------- | -------------------------- |
| 0.1.0   | ✅ Released | Flutter foundation started |
| 0.2.0   | ⏳ Planned  | Authentication             |
| 0.3.0   | ⏳ Planned  | Directorate Module         |
| 0.4.0   | ⏳ Planned  | Department Module          |
| 0.5.0   | ⏳ Planned  | Vehicle Module             |
| 0.6.0   | ⏳ Planned  | Driver Module              |
| 0.7.0   | ⏳ Planned  | Personnel Module           |
| 0.8.0   | ⏳ Planned  | Assignment Module          |
| 0.9.0   | ⏳ Planned  | Reports                    |
| 1.0.0   | 🎯 Target  | First Production Release   |

---

# Changelog Rules

Every completed development session should update this file.

Entries should include:

* New features
* Fixed bugs
* Refactoring
* Documentation updates
* Breaking changes (if any)

Commit messages and changelog entries should remain consistent whenever possible.
