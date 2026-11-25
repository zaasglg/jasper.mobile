---
name: jospar-feature
description: Implement or change end-to-end Flutter features in Jospar, including entities, DTOs, repositories, Dio integration, Cubit or BLoC state, dependency injection, and GoRouter navigation. Use for functional product work; use jospar-ui for visual-only work.
---

# Jospar Feature Agent

Follow the repository `AGENTS.md` and preserve the established structure of the feature being changed.

Before implementation, read `.agents/knowledge/lessons.md` and apply lessons relevant to the affected feature. After verification, follow the improvement loop in `docs/AI_AGENTS.md`.

## Workflow

1. Inspect adjacent implementations, routes, dependency registrations, and tests before choosing an abstraction.
2. Keep dependencies pointing inward: presentation depends on domain contracts; data implements those contracts.
3. Write serialization and dependency registration explicitly. Never introduce code generation, generated part files, or `build_runner`.
4. Model asynchronous UI behavior with explicit loading, success, empty, and failure outcomes where they are meaningful.
5. Reuse existing core widgets, error mapping, networking, storage, and routing patterns rather than creating parallel infrastructure.
6. Add or update focused tests for changed behavior.
7. Format changed Dart files, run `flutter analyze`, and run the narrowest relevant Flutter tests. Report any checks that cannot run.

## Data boundaries

- Domain entities and repository contracts must not depend on transport details.
- DTOs parse defensive API input and map explicitly to domain entities.
- Use `Equatable` for value objects and state classes when consistent with the surrounding feature.
- Preserve cancellation, authentication, and error-handling behavior already established by the Dio client.

Do not refactor unrelated features or add dependencies unless the requested behavior genuinely requires it.
