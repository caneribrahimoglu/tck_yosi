# TCK YÖSİ

> **TCK Yönetim Sistemi (YÖSİ)**
> Cross-platform management system developed with Flutter.

---

# Project Vision

TCK YÖSİ is a modular management system designed for directorates and departments.

The project is not intended as a prototype. It is being developed as a scalable commercial software product that can grow over many years.

Primary target platforms:

* Android
* iOS
* Windows
* Web

Backend (Phase 1)

* Firebase

Future Backend

* FastAPI
* PostgreSQL

---

# Project Goals

The system will eventually include:

* Directorate Management
* Department Management
* Vehicle Management
* Driver Management
* Personnel Management
* Live Vehicle Tracking
* Vehicle Handover / Return Records
* Fuel Tracking
* Mileage Tracking
* Vehicle Issue Tracking
* Work Assignment Management
* Working Hours
* Leave Management
* Reports
* Dashboard
* Notification System

The architecture is designed so that new modules can be added without affecting existing modules.

---

# Development Philosophy

This project follows several important software engineering principles.

* Feature First Architecture
* Single Responsibility Principle (SRP)
* Separation of Concerns
* Reusable Widgets
* Clean Code
* Long-Term Maintainability
* Commercial Software Standards

The objective is not only to build a working application but also to establish a maintainable architecture that can evolve over many years.

---

# Architecture

The project uses Feature First Architecture.

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

Every feature owns its own:

* Models
* Pages
* Widgets
* Repositories

Example:

```text
vehicles/
    data/
    models/
    pages/
    repositories/
    widgets/
```

---

# Current Progress

## ✅ Phase 01

Project created.

Flutter environment configured.

Android Studio connected.

Project structure prepared.

Architecture Guide created.

---

## ✅ Phase 02

Main application entry created.

Files created:

```text
main.dart
app/app.dart
features/dashboard/pages/dashboard_page.dart
```

Current application flow:

```text
main.dart
      │
      ▼
runApp()
      │
      ▼
TckYosiApp
      │
      ▼
MaterialApp
      │
      ▼
DashboardPage
      │
      ▼
Scaffold
```

The application successfully launches and displays the first Dashboard screen.

---

# What Has Been Learned

During development, the following Flutter concepts have been studied:

* main()
* runApp()
* MaterialApp
* Scaffold
* StatelessWidget
* build()
* Widget Tree (Introduction)
* const constructors
* Project architecture
* Single Responsibility Principle

The goal is to understand *why* each component exists rather than simply writing code.

---

# Coding Standards

Naming

Files:

```text
snake_case
```

Classes:

```text
PascalCase
```

Variables

```text
camelCase
```

Business logic must never be written inside UI pages.

Repositories communicate with Firebase.

Pages only display data.

---

# Git Commit Convention

Examples

```text
feat: create dashboard page

feat: add vehicle repository

fix: correct vehicle filter

refactor: move firebase logic to repository

docs: update architecture guide
```

---

# Learning Strategy

The project is being developed as a guided senior-level mentoring process.

Each topic is studied in the following order:

1. Why it exists
2. How it works
3. Where it should be used
4. Best practices
5. Real project implementation

The objective is to understand software architecture instead of memorizing Flutter syntax.

---

# Next Milestones

Upcoming development roadmap:

* Widget Tree
* BuildContext
* StatefulWidget
* Theme System
* Router
* Navigation
* Dashboard UI
* Authentication
* Firebase Integration
* Directorate Module
* Department Module
* Vehicle Module
* Driver Module
* Personnel Module
* Reporting Module

After the Flutter foundation is complete, the project will continue with production-ready business modules.