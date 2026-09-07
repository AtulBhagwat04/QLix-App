<div align="center">

  <img src="assets/images/app_logo.png" alt="QLix Client Logo" width="100" height="100" style="border-radius: 20px;" />

  # QLix Client

  ### Cross-Platform Real-Time Audience Engagement Flutter Application

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![BLoC](https://img.shields.io/badge/State_Management-BLoC_9.x-blueviolet?style=for-the-badge)](https://bloclibrary.dev)
  [![Clean Architecture](https://img.shields.io/badge/Architecture-Feature--First_Clean_Arch-teal?style=for-the-badge)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

</div>

---

## 📱 Overview

**QLix Client** is the cross-platform application powering the QLix audience engagement platform on **iOS, Android, Web, macOS, Windows, and Linux**.

It delivers two synchronized real-time experiences:
1. **Presenter / Host Experience**: Create sessions, toggle live polls, launch competitive quizzes, moderate incoming crowd questions, and display a projector-optimized presenter screen with dynamic QR code access.
2. **Audience / Participant Experience**: Instant frictionless join (via 6-digit access code or QR scan without requiring an account), live interactive voting, Q&A question submission & upvoting, and gamified quiz participation.

---

## 🏛 Clean Architecture & Engineering Standards

The codebase adheres strictly to the **Feature-First + Clean Architecture + Repository Pattern + BLoC State Management** structure defined in [GEMINI.md](file:///d:/Development/Flutter/Flutter%20Projects/QLix/GEMINI.md).

```
Presentation Layer (UI, BLoCs, Widgets)
        │
        ▼ (depends on contracts & entities)
   Domain Layer (Entities, Use Cases, Repository Interfaces)
        ▲
        │ (implements contracts)
   Data Layer (Data Sources, DTOs, Cache, Remote Repositories)
```

### Layer Responsibilities

```text
lib/
├── core/                           # Cross-cutting foundational modules
│   ├── constants/                  # Colors, dimensions, typography, icons, string constants
│   ├── di/                         # Dependency injection root (GetIt service locator)
│   ├── network/                    # Dio REST ApiClient & SocketIO SocketClient
│   ├── router/                     # GoRouter configuration, route definitions & auth guards
│   ├── storage/                    # FlutterSecureStorage & Hive CacheManager
│   ├── theme/                      # Light & Dark theme definitions (AppTheme)
│   ├── utils/                      # Formatting, debounce, error parser helpers
│   └── widgets/                    # Reusable atomic UI components (buttons, badges, dialogs)
│
└── features/                       # Independent feature modules (Feature-First)
    ├── analytics/                  # Session analytics, charts & reports
    ├── auth/                       # Host authentication & session management
    ├── polls/                      # Live polling, voting & results
    ├── presenter/                  # Large-display projector presentation view
    ├── qa/                         # Audience Q&A with upvoting & moderation
    ├── quiz/                       # Timed quizzes & live scoring leaderboards
    └── sessions/                   # Session creation, live control & dashboard
```

Each feature module is structured into three distinct layers:
```text
features/<feature_name>/
├── data/
│   ├── datasources/                # Remote API / Local cache / Socket sources
│   ├── models/                     # DTOs (Data Transfer Objects) with JSON serialization
│   └── repositories/               # Concrete repository implementations
├── domain/
│   ├── entities/                   # Core business models (immutable, Equatable)
│   ├── repositories/               # Abstract repository contracts / interfaces
│   └── usecases/                   # Feature use cases & business logic
└── presentation/
    ├── blocs/                      # BLoCs & Cubits (Events, States)
    ├── screens/                    # High-level route screens
    └── widgets/                    # Modular, feature-specific sub-widgets
```

---

## 🔄 State Management (BLoC Pattern)

State updates follow a strict unidirectional reactive cycle:

```
[ User Interaction ]
         │
         ▼ (dispatches)
      [ Event ]
         │
         ▼ (handled by)
       [ BLoC ]
         │
         ▼ (invokes)
  [ Domain Repository ]
         │
         ▼ (fetches via)
   [ Data Source ]
         │
         ▼ (emits)
      [ State ] (Immutable, Equatable)
         │
         ▼ (triggers)
   [ UI Re-render ]
```

### State Design Rules
* All state objects are immutable and implement `Equatable`.
* Features explicitly model states: `Initial`, `Loading`, `Success`, `Failure` (with user-friendly error messages), and `Empty`.
* Widgets remain purely presentational: no direct HTTP, WebSocket, or storage calls inside widgets.

---

## 🧭 Navigation & Route Hierarchy

Navigation is driven by [`go_router`](https://pub.dev/packages/go_router) with integrated authentication guards:

| Path | Screen | Access Level | Description |
| :--- | :--- | :---: | :--- |
| `/` | `ParticipantJoinScreen` | Public | Direct join input with PIN code or QR scanner |
| `/splash` | `HostSplashWidget` | Public | Initial token verification & routing splash |
| `/login` | `HostLoginScreen` | Public | Host credential authentication |
| `/signup` | `HostSignupScreen` | Public | Host account registration |
| `/dashboard` | `HostDashboardScreen` | Authenticated | Host session management & overview statistics |
| `/session/create` | `CreateSessionScreen` | Authenticated | Create a new interactive engagement session |
| `/session/control/:id` | `HostLiveControlScreen` | Authenticated | Host real-time command center for live sessions |
| `/session/:code` | `ParticipantWorkspaceScreen`| Public | Participant live voting, Q&A, and quiz workspace |
| `/presenter/:code` | `PresenterModeScreen` | Public | Large-screen display for projectors with live QR code |
| `/analytics/:id` | `AnalyticsDashboardScreen`| Authenticated | Post-session graphs, engagement metrics & export |

---

## 🔌 Network & Real-Time Client

### REST Client (`ApiClient`)
* Configured using [`dio`](https://pub.dev/packages/dio).
* Automated Bearer token injection via `SecureStorageService`.
* Automatic base URL resolution supporting both production (`https://qlix-app.onrender.com`) and local development IPs.

### WebSocket Client (`SocketClient`)
* Built on [`socket_io_client`](https://pub.dev/packages/socket_io_client).
* Manages room subscriptions, event callbacks, heartbeat pings, and reconnection logic.
* Supported WebSocket events:
  - `join_session`, `session_updated`
  - `poll_started`, `submit_vote`, `poll_results_updated`
  - `new_question`, `question_broadcast`, `upvote_question`
  - `quiz_question_active`, `quiz_submit`, `quiz_leaderboard`

---

## 📦 Key Dependencies

| Package | Purpose |
| :--- | :--- |
| `flutter_bloc` | Predictable state management following BLoC pattern |
| `go_router` | Declarative routing with URL parameter support & redirect guards |
| `dio` | Powerful HTTP networking client with interceptors |
| `socket_io_client` | Real-time WebSocket connection to the backend cluster |
| `hive_flutter` | Lightweight, blazing-fast local key-value cache |
| `flutter_secure_storage`| Hardware-backed keychain/keystore token storage |
| `fl_chart` | Interactive animated bar, line, and pie charts |
| `flutter_animate` | Fluid micro-animations for cards, badges, and state transitions |
| `qr_flutter` & `mobile_scanner` | QR code generation and real-time camera scanning |
| `get_it` | Inversion of control and dependency injection container |
| `equatable` | Value equality for domain entities and BLoC states |

---

## 🛠 Setup & Run Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Backend Host (Optional)

By default, the client points to the live backend service at `https://qlix-app.onrender.com`.

If running against a local server (`localhost` or LAN IP), update the host configuration in [api_client.dart](file:///d:/Development/Flutter/Flutter%20Projects/QLix/client/lib/core/network/api_client.dart) and [socket_client.dart](file:///d:/Development/Flutter/Flutter%20Projects/QLix/client/lib/core/network/socket_client.dart).

### 3. Run the Application

```bash
# Web (recommended for testing Presenter and Participant modes side-by-side)
flutter run -d chrome

# Android / iOS
flutter run

# Desktop
flutter run -d windows    # Windows
flutter run -d macos      # macOS
flutter run -d linux      # Linux
```

---

## 🧪 Code Quality & Analysis

Maintain clean, standardized code before every commit:

```bash
# Run Flutter static analyzer
flutter analyze

# Format all Dart files
dart format .

# Run test suite
flutter test
```

### Strict Engineering Rules Reminder
- **No Direct API calls from UI**: Keep widgets decoupled from networking.
- **No Raw Untyped Maps in Widgets**: Use typed Domain entities.
- **Widget Decomposition**: Keep files focused; extract reusable sub-widgets when reaching ~300 lines.

---

<div align="center">
  <sub>Part of the <b>QLix</b> Enterprise Audience Engagement Platform</sub>
</div>
