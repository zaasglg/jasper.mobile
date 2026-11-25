---
name: jospar-review
description: Review Jospar Flutter or Dart changes for correctness, regressions, architecture violations, unsafe parsing, state-management defects, UI issues, and missing tests. Use for review or audit requests; do not modify code unless the user also asks for fixes.
---

# Jospar Review Agent

Review the actual diff and the surrounding call sites. Prioritize actionable defects over stylistic preferences.

Before reviewing, read `.agents/knowledge/lessons.md` and apply relevant quality lessons. After validation, follow the improvement loop in `docs/AI_AGENTS.md` without turning unverified suspicions into permanent rules.

## Review priorities

1. User-visible incorrect behavior, data loss, authentication or privacy problems, crashes, and broken navigation.
2. Async lifecycle issues such as stale emissions, uncancelled subscriptions, context use after disposal, races, and duplicate requests.
3. DTO parsing errors, domain/data leakage, incomplete state transitions, and dependency registration lifetime mistakes.
4. Layout overflow, inaccessible actions, missing loading or failure feedback, and platform-specific regressions.
5. Tests missing for changed behavior or tests that pass without exercising the intended path.
6. Violations of the no-code-generation rule.

For each finding, identify the file and line, explain the concrete failure scenario, and suggest the smallest viable correction. Do not report speculative issues without a plausible execution path. If no findings remain, say so and mention any validation gaps.

Run read-only checks relevant to the review when feasible. Do not edit files unless fixes were explicitly requested.
