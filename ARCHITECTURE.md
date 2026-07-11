# TCK YÖSİ - Architecture Guide

---

# 1. Project Overview

## Project Name

```text
tck_yosi
```

## Product Name

```text
TCK YÖSİ
```

## Description

TCK YÖSİ is a cross-platform management system developed for directorates and departments.

The project is designed as a scalable commercial software product and follows modern software architecture principles.

Target platforms:

* Android
* iOS
* Windows
* Web

---

# 2. Project Vision

The goal is to build a modular management platform capable of serving multiple organizations in the future.

The system should remain maintainable even after years of development.

Every architectural decision should support long-term scalability.

---

# 3. Business Structure

Real-world hierarchy

```text
Directorate
    │
    ├── Department
    │       │
    │       ├── Vehicles
    │       ├── Drivers
    │       ├── Personnel
    │       ├── Assignments
    │       └── Reports
```

Every business record should always belong to a Department.

Departments belong to a Directorate.

Future versions may support multiple directorates inside one installation.

---

# 4. Architecture Style

The project follows **Feature First Architecture**.

```text
lib/
│
├── app/
│   ├── app.dart
│   └── router.dart
│
├── core/
│   ├── constants/
│   ├── enums/
│   ├── extensions/
│   ├── theme/
│   └── utils/
│
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── directorates/
│   ├── departments/
│   ├── vehicles/
│   ├── drivers/
│   ├── personnel/
│   ├── assignments/
│   └── reports/
│
├── shared/
│   ├── services/
│   └── widgets/
│
└── main.dart
```

Every feature owns its own architecture.

Example

```text
vehicles/
│
├── data/
├── models/
├── pages/
├── repositories/
└── widgets/
```

Modules should never become dependent on each other's internal structure.

---

# 5. Layer Responsibilities

## app/

Responsible for application configuration.

Contains:

* MaterialApp
* Router
* Global Navigation
* Application bootstrap

---

## core/

Contains global resources.

Examples:

* Constants
* Enums
* Theme
* Extensions
* Utility classes

Core never contains business logic.

---

## features/

Contains business modules.

Each module manages its own:

* Models
* Pages
* Widgets
* Repositories

Every feature should be independently maintainable.

---

## shared/

Contains reusable components shared by multiple modules.

Examples

* CustomButton
* LoadingWidget
* DialogService
* DateFormatter

If a widget belongs to only one feature, it should stay inside that feature.

---

# 6. Coding Principles

The project follows:

* Single Responsibility Principle (SRP)
* Separation of Concerns
* Feature Isolation
* Reusable Components
* Clean Code
* Readability First

Every file should have only one clear responsibility.

---

# 7. Naming Rules

## Files

Use snake_case

```text
vehicle_repository.dart
vehicle_list_page.dart
driver_card.dart
```

---

## Classes

Use PascalCase

```dart
class Vehicle {}

class VehicleRepository {}

class DashboardPage {}
```

---

## Variables

Use camelCase

```dart
final currentVehicle;

final totalKm;
```

---

## Constants

Prefer lowerCamelCase for Dart constants.

```dart
const appName = 'TCK YÖSİ';
```

---

# 8. Model Rules

Models represent business entities.

Examples

* Directorate
* Department
* Vehicle
* Driver
* Personnel

Rules

* Immutable
* final fields
* const constructors whenever possible
* No unnecessary properties

Example

```dart
class Vehicle {

  final String id;
  final String plate;
  final bool isActive;

  const Vehicle({
    required this.id,
    required this.plate,
    required this.isActive,
  });

}
```

---

# 9. Repository Rules

Pages never communicate directly with Firebase.

Architecture flow

```text
UI

↓

Controller / ViewModel

↓

Repository

↓

Firebase
```

Repositories are responsible for data access only.

---

# 10. Firebase Rules

Never write Firebase code inside Widgets.

Wrong

```dart
FirebaseFirestore.instance.collection('vehicles').get();
```

Correct

```text
Page

↓

Repository

↓

Firebase
```

Collections

```text
directorates

departments

vehicles

drivers

personnel

assignments
```

---

# 11. UI Rules

Widgets display data.

Business logic belongs outside UI.

Large pages should be split into reusable widgets.

Example

```text
dashboard/

pages/

widgets/

models/

repositories/
```

DashboardPage should become an orchestrator instead of a very large file.

---

# 12. Git Rules

Preferred commits

```text
feat: create dashboard page

feat: add vehicle repository

fix: correct department filter

refactor: split dashboard widgets

docs: update architecture guide
```

Avoid

```text
update

last version

changes

fix
```

---

# 13. Current Project Status

Completed

* Flutter project created
* Feature First Architecture established
* Folder structure prepared
* ARCHITECTURE.md created
* Application entry point created
* app.dart created
* DashboardPage created
* First application successfully running

Current flow

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

---

# 14. Future Roadmap

Flutter Foundation

* Widget Tree
* BuildContext
* StatelessWidget
* StatefulWidget
* Theme
* Router
* Navigation

Business Modules

* Authentication
* Directorate Management
* Department Management
* Vehicle Management
* Driver Management
* Personnel Management
* Assignments
* Reports

Infrastructure

* Firebase Authentication
* Cloud Firestore
* Firebase Storage
* Push Notifications

Future Backend

* FastAPI
* PostgreSQL
* REST API
* Offline Synchronization

---

# 15. Golden Rules

* Think before coding.
* Keep files small.
* Every architectural decision must have a reason.
* Build simple first.
* Scale only when necessary.
* Never mix UI with business logic.
* Prefer readability over clever code.
* Design for long-term maintainability.
* Write code as if another senior developer will maintain it.
