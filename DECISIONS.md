# TCK YÖSİ - Decisions Log

> This document records important architectural and technical decisions made during the development of TCK YÖSİ.

The purpose of this file is to preserve the reasoning behind decisions so they remain understandable months or years later.

---

# Decision Format

Each decision should include:

* ID
* Date
* Title
* Status
* Context
* Decision
* Consequences

Possible Status values:

* Accepted
* Proposed
* Rejected
* Deprecated
* Superseded

---

# ADR-001

## Date

2026-07-09

## Title

Feature First Architecture

## Status

Accepted

## Context

The project is expected to grow into a large commercial application with many independent modules.

A traditional layer-based structure would become difficult to maintain as the project grows.

## Decision

The project will follow **Feature First Architecture**.

Every business module owns its own:

* Models
* Pages
* Repositories
* Widgets

Example

```text
vehicles/
├── data/
├── models/
├── pages/
├── repositories/
└── widgets/
```

## Consequences

Advantages

* Better scalability
* Easier maintenance
* Independent modules
* Clear project structure

Trade-offs

* Slightly more folders
* New developers need to understand the architecture

---

# ADR-002

## Date

2026-07-09

## Title

Firebase as Initial Backend

## Status

Accepted

## Context

The project needs rapid development without spending time building a backend from scratch.

## Decision

Phase 1 backend will use Firebase.

Services

* Firebase Authentication
* Cloud Firestore
* Firebase Storage

## Consequences

Advantages

* Faster development
* Less infrastructure
* Cross-platform support

Trade-offs

* Vendor dependency
* Some limitations for complex reporting

Future migration planned:

```text
FastAPI

↓

PostgreSQL
```

---

# ADR-003

## Date

2026-07-09

## Title

Repository Pattern

## Status

Accepted

## Context

Business logic should not depend directly on Firebase.

Future backend changes should require minimal UI changes.

## Decision

All data access must go through repositories.

Architecture

```text
UI

↓

Controller / ViewModel

↓

Repository

↓

Firebase
```

## Consequences

Advantages

* Easier testing
* Easier backend migration
* Better separation of concerns

---

# ADR-004

## Date

2026-07-09

## Title

Application Entry Structure

## Status

Accepted

## Context

Avoid placing application configuration inside main.dart.

## Decision

Application startup flow will be:

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
```

main.dart should remain minimal.

Application configuration belongs inside:

```text
app/app.dart
```

## Consequences

Advantages

* Cleaner startup
* Easier maintenance
* Better separation of responsibilities

---

# ADR-005

## Date

2026-07-09

## Title

One Responsibility Per File

## Status

Accepted

## Context

Large Flutter projects often become difficult to maintain when files have multiple responsibilities.

## Decision

Each file should have a single responsibility.

Examples

```text
DashboardPage
```

Displays dashboard.

```text
VehicleRepository
```

Accesses vehicle data.

```text
Vehicle
```

Represents a vehicle.

## Consequences

Advantages

* Easier navigation
* Smaller files
* Better readability
* Simpler maintenance

---

# ADR-006

## Date

2026-07-09

## Title

Documentation First

## Status

Accepted

## Context

The project is expected to continue for years.

Without documentation, architectural decisions may be forgotten.

## Decision

The following documents will always be maintained:

* README.md
* ARCHITECTURE.md
* ROADMAP.md
* CHANGELOG.md
* DECISIONS.md

Documentation should be updated whenever significant changes are introduced.

## Consequences

Advantages

* Easier onboarding
* Better project memory
* Clear development direction
* Long-term maintainability

---

# Future Decisions

This section will contain future architectural decisions.

Examples

* State Management selection
* Dependency Injection
* Offline database
* API strategy
* Synchronization strategy
* Push notification architecture
* Logging system
* Error handling strategy
* Testing strategy
* CI/CD pipeline
* Localization
* Security policies

---

# Decision Rules

A new decision should be recorded when:

* Project architecture changes.
* A new technology is adopted.
* A significant design choice is made.
* An existing architectural decision is replaced.
* A long-term technical direction is established.

Small implementation details should **not** be recorded here.

This document is intended for decisions that influence the long-term evolution of the project.
