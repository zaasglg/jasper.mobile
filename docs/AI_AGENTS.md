# AI Agents in Jospar

This document describes the project-specific Codex agents, how they are selected, and how they improve from verified project experience.

## Available agents

| Agent | Use it for | Explicit invocation |
| --- | --- | --- |
| Jospar Feature Agent | End-to-end features, domain/data/presentation layers, Dio, repositories, Cubit/BLoC, DI, and GoRouter | `$jospar-feature` |
| Jospar UI Agent | Screens, widgets, responsive layouts, accessibility, forms, dialogs, and visual polish | `$jospar-ui` |
| Jospar Testing Agent | Unit, widget, golden, navigation, repository, and regression tests | `$jospar-testing` |
| Jospar Review Agent | Read-only review for correctness, regressions, architecture, state, UI, and test gaps | `$jospar-review` |
| Jospar Idea Council | Multi-agent discussion, challenge, voting, and one shared recommendation with dissent preserved | `$jospar-idea-council` |

Codex can select an agent automatically from the task description. Use the explicit invocation when a particular workflow must be selected.

## Where agent configuration lives

```text
AGENTS.md                         Repository-wide requirements and routing
.agents/skills/<agent>/SKILL.md  Agent-specific workflow
.agents/knowledge/lessons.md     Shared verified project lessons
docs/AI_AGENTS.md                Human-facing documentation
```

`AGENTS.md` remains the source of truth for mandatory repository conventions. A skill may specialize the workflow but must not override those conventions.

## Continuous improvement loop

Every project agent follows this loop:

1. Read `.agents/knowledge/lessons.md` before making implementation decisions.
2. Complete and verify the requested task.
3. At the end, evaluate whether the work revealed a reusable project lesson.
4. Add or update a lesson only when evidence meets the acceptance rules below.
5. If a lesson changes how one agent should behave, update that agent's `SKILL.md` as part of the same task and validate the skill.

This process improves repository guidance across sessions. It does not retrain or alter the underlying AI model.

## Lesson acceptance rules

A lesson must be:

- specific to Jospar or a recurring workflow in this repository;
- supported by a failing/passing test, analyzer output, runtime evidence, user correction, or an established code pattern;
- reusable in future tasks rather than tied to a single temporary implementation;
- concise and actionable;
- free of secrets, credentials, personal data, raw production payloads, and unsupported speculation.

Do not record generic Flutter advice, duplicate an existing lesson, or turn a one-off workaround into a permanent rule. Update or remove stale lessons when the codebase changes.

## Lesson format

Add entries under the relevant category in `.agents/knowledge/lessons.md`:

```markdown
### Short lesson title

- Date: YYYY-MM-DD
- Scope: feature | UI | testing | review | shared
- Evidence: test, analyzer, runtime result, user correction, or code reference
- Lesson: the reusable rule or decision
- Apply when: the condition that makes the lesson relevant
```

## Examples

```text
$jospar-feature add workspace invitation support
$jospar-ui make the project details screen responsive
$jospar-testing reproduce and cover the duplicate-message bug
$jospar-review review the current working tree
$jospar-idea-council should we add an AI task-planning assistant?
```

For work spanning implementation and tests, Codex may use multiple agents in the smallest useful sequence, such as `jospar-feature` followed by `jospar-testing`.

## Idea Council

The Idea Council is intended for decisions rather than implementation. It asks independent voices to judge the same neutral brief from user, product, technical, business, and risk perspectives. At least three perspectives are required; five are preferred.

Each voice votes independently before cross-examination. The chair then reports the vote count, confidence, decisive reasoning, strongest dissent, and smallest next step. A tied or weakly evidenced vote leads to a reversible experiment rather than false certainty.
