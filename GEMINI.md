# QLix Project Architecture & Engineering Guidelines

This document outlines the architectural standards and engineering principles for this repository. All code additions, modifications, and refactors must strictly comply with these rules.

---

## 1. Core Architecture Approach

Follow: **Feature-First + Clean Architecture + Repository Pattern + BLoC State Management**

* Organize the application by features (`features/<feature_name>/`).
* Each feature contains its own **Presentation**, **Domain**, and **Data** layers.
* Maintain a strict separation of concerns at all times.

---

## 2. Architectural Layers & Responsibilities

### Presentation Layer (`presentation/`)
* **Responsibilities**:
  * User Interface (Widgets, Screens, Dialogs, Bottom Sheets).
  * User interactions and input events.
  * State management coordination (BLoC / Cubit).
  * Displaying data and handling error / loading / empty UI states.
* **Rules**:
  * UI must **never** directly call APIs, databases, or external sockets.
  * UI must **not** contain complex business logic or raw data transformations.
  * Keep widgets small, modular, and focused on presentation.
  * Extract feature-specific sub-widgets into `presentation/widgets/`.
  * Avoid massive monolithic widget files (>300 lines should be evaluated for decomposition).

### Domain Layer (`domain/`)
* **Responsibilities**:
  * Core business entities (plain Dart classes with Equatable/immutability).
  * Business rules and validations.
  * Repository contracts / interfaces (e.g. `abstract class ISessionRepository`).
  * Use cases / interactors when meaningful business logic exists.
* **Rules**:
  * Domain logic must remain **100% independent** from UI, Flutter framework specifics, APIs, and databases.
  * Repository contracts describe *what* the application needs, not *how* data is fetched.
  * Avoid unnecessary boilerplate abstractions for trivial CRUD pass-throughs unless required for domain rules or contract inversion.

### Data Layer (`data/`)
* **Responsibilities**:
  * Data sources: Remote API communication (Dio), WebSocket/Socket.IO, Local storage (Hive, FlutterSecureStorage).
  * Data models (DTOs) handling JSON serialization / deserialization.
  * Repository implementations implementing domain contracts.
* **Rules**:
  * External services and SDKs must be accessed **only** through data sources.
  * Data models must convert between external JSON/DB schemas and clean Domain entities.
  * Implementation details (endpoints, query params, HTTP status codes, socket events) must **never** leak into the Presentation layer.

---

## 3. Dependency Flow

Maintain strict unidirectional dependency flow:

```
Presentation ──► Domain ◄── Data
```

* Presentation depends on Domain (entities, use cases, repository contracts).
* Data depends on Domain (implements repository contracts).
* **Strictly Prohibited**:
  * Domain depending on Presentation or Data implementations.
  * UI directly accessing APIs, databases, or data sources.
  * BLoC / Cubits directly calling HTTP/Dio/Socket clients without a Repository.

---

## 4. State Management (BLoC / Cubit)

* Flow: `User Interaction` ──► `Event` ──► `BLoC` ──► `Domain/Repository` ──► `Data Source` ──► `State` ──► `UI Update`.
* Keep state objects immutable (`Equatable` / copyWith).
* Explicitly model distinct states: Initial, Loading, Success, Failure (with user-friendly error messages), and Empty.
* Keep BLoCs focused on a single feature / domain workflow; do not merge unrelated domains into a god BLoC.

---

## 5. Repository Pattern

* Business logic & BLoCs depend on repository abstractions (`domain/repositories/`).
* Repository implementations (`data/repositories/`) coordinate data sources (e.g., fetch remote, cache locally, emit cached data on offline).
* Repositories return clean domain models, typed Results/Failures, never raw `Map<String, dynamic>`.

---

## 6. Anti-Patterns to Avoid

* **God Classes**: Avoid single files with thousands of lines mixing UI, state, parsing, and navigation.
* **Raw JSON in UI**: Avoid parsing `session['title']` or untyped maps directly inside widgets.
* **Bypassing Layers**: No network calls, storage reads, or socket emits from Flutter widgets.
* **Overengineering**: Apply Clean Architecture pragmatically; keep simple features clean and avoid excessive layers for trivial operations.
