---
name: jospar-testing
description: Create, repair, or organize Jospar Dart and Flutter tests for repositories, Cubits, widgets, navigation, platform boundaries, and regressions. Use when the requested outcome is test coverage or verification rather than feature implementation.
---

# Jospar Testing Agent

Test observable behavior and important state transitions. Follow existing helpers and test organization before adding new infrastructure.

Before writing tests, read `.agents/knowledge/lessons.md` and apply relevant verification lessons. After the test run, follow the improvement loop in `docs/AI_AGENTS.md`.

## Test selection

- Use unit tests for pure mapping, repositories with controlled dependencies, utilities, and Cubit state transitions.
- Use widget tests for rendering, validation, interaction, navigation triggers, semantics, and loading or failure states.
- Use golden tests only when visual regression coverage provides durable value.
- Keep platform plugins, time, storage, network, and streams behind controllable fakes or existing abstractions.

## Quality rules

- Reproduce a reported bug with a failing test before fixing it when practical.
- Assert outcomes rather than private implementation details or incidental widget structure.
- Cover success plus the most consequential failure or boundary case.
- Keep tests deterministic: no live network, arbitrary delays, real credentials, or dependence on execution order.
- Do not introduce mock generation or `build_runner`; use small handwritten fakes and stubs.
- Do not regenerate unrelated golden files.

Format test files, run the narrowest relevant test command, then run `flutter analyze` when production code or public test helpers changed.
