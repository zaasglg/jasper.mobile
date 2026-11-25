# AGENTS.md — Jospar Me (Flutter Project)

This document provides instructions and guidelines for AI Agents (and developers) working on the **Jospar Me** Flutter project.

---

## 🎯 Project Overview & Tech Stack

**Jospar Me** is built using Flutter with a clean, production-ready stack designed for high reliability and zero build-runner complexity.

### Core Stack & Packages (`pubspec.yaml`)

- **State Management & Architecture:** `flutter_bloc`, `equatable`
- **Dependency Injection (DI):** `get_it`
- **Networking:** `dio`
- **Navigation:** `go_router`
- **Local Storage:** `shared_preferences`, `flutter_secure_storage`
- **UI & Media:** `cached_network_image`, `flutter_svg`, `google_fonts`

> ⚠️ **CRITICAL REQUIREMENT:** **NO `build_runner` or code generators allowed.**
> All models, serialization/deserialization, BLoC states, and dependency registrations must be written explicitly in pure Dart using `Equatable`.

---

## 📦 Dependencies Reference (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Architecture & State Management
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  get_it: ^7.7.0

  # Networking & Routing
  dio: ^5.4.3+1
  go_router: ^14.2.0

  # Storage
  shared_preferences: ^2.2.3
  flutter_secure_storage: ^9.2.2

  # UI & Media
  cached_network_image: ^3.3.1
  flutter_svg: ^2.0.10+1
  google_fonts: ^6.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

---

## 🏗 Architecture & Code Patterns

### 1. Folder Structure (`lib/`)

```
lib/
├── core/
├── ├── network/          # Dio client instance & interceptors
├── ├── router/           # GoRouter configuration
├── ├── storage/          # SharedPreferences & Secure Storage wrappers
├── ├── theme/            # GoogleFonts, colors, UI constants
├── └── di/               # GetIt injection setup (`service_locator.dart`)
├── features/
│   └── <feature_name>/
│       ├── data/         # Models (`fromJson`/`toJson`), Repositories implementation
│       ├── domain/       # Repository interfaces, Use Cases / Entities
│       └── presentation/ # BLoC / Cubit, Screens, Widgets
└── main.dart
```

---

## 📝 Conventions & Rules for AI Agents

### 1. Data Models (No CodeGen)

Every model **must** extend `Equatable` and explicitly implement `fromJson()`, `toJson()`, and `copyWith()`.

```dart
import 'package:equatable/equatable.dart';

class TaskModel extends Equatable {
  final String id;
  final String title;
  final bool isCompleted;

  const TaskModel({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
  };

  TaskModel copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [id, title, isCompleted];
}
```

### 2. Dependency Injection (`get_it`)

Register dependencies manually in `lib/core/di/service_locator.dart`:

```dart
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

final sl = GetIt.instance;

void setupServiceLocator() {
  // Core
  sl.registerLazySingleton<Dio>(() => Dio());

  // Repositories & Services
  // sl.registerLazySingleton<TaskRepository>(() => TaskRepositoryImpl(dio: sl()));

  // BLoCs / Cubits
  // sl.registerFactory(() => TaskBloc(repository: sl()));
}
```

### 3. State Management (`flutter_bloc`)

- Extend `Equatable` for both BLoC Events and States.
- Always handle `Loading`, `Success`, and `Failure` states gracefully.

---

## 🚀 Workflow Checklist for Agents

When generating or modifying code in **Jospar Me**:

1. Do **NOT** introduce packages that require `build_runner` (e.g., `freezed`, `json_serializable`, `injectable`, `hive_generator`).
2. Do **NOT** reference `.g.dart` or `.freezed.dart` files.
3. Use `Dio` for API calls and wrap responses in explicit model parsers.
4. Use `GoRouter` for all screen transitions.
5. Use `GoogleFonts` and `FlutterSvg` for UI assets.

---

## 🤖 Project Agent Routing

Project-specific agents are implemented as Codex skills under `.agents/skills/`:

- Use `jospar-feature` for end-to-end product functionality, repositories, DTOs, Cubits/BLoCs, DI, and routing.
- Use `jospar-ui` for screens, widgets, responsive layout, accessibility, and visual polish.
- Use `jospar-testing` when the requested outcome is test coverage, regression reproduction, or test repair.
- Use `jospar-review` for code-review and audit requests. Review is read-only unless the user also requests fixes.
- Use `jospar-idea-council` when the user wants multiple independent opinions, structured debate, voting, or a shared decision about an idea.

When a task clearly matches one of these skills, read its complete `SKILL.md` before acting. If multiple skills apply, use the smallest set that covers the request and state their order. Explicit invocations such as `$jospar-feature` or `$jospar-review` take precedence.

Full agent documentation is maintained in `docs/AI_AGENTS.md`.

### Continuous Agent Improvement

Before project work, selected agents must read `.agents/knowledge/lessons.md` and apply relevant verified lessons. At the end of a completed task, evaluate whether the work produced a reusable project-specific lesson. Record it only when it satisfies the acceptance rules in `docs/AI_AGENTS.md`; do not add generic advice, speculation, secrets, personal data, or duplicate entries.

If a verified lesson changes an agent workflow, update the relevant `SKILL.md` and run the skill validator. Continuous improvement changes repository guidance only; it does not retrain the underlying model.
