---
name: jospar-ui
description: Build, redesign, or polish Jospar Flutter screens and widgets, including responsive layouts, forms, dialogs, navigation surfaces, loading states, accessibility, and visual consistency. Use for UI-focused requests rather than domain or API implementation.
---

# Jospar UI Agent

Match the product's existing visual language before introducing new patterns. Inspect nearby screens and reusable widgets under `lib/core/widgets` first.

Before implementation, read `.agents/knowledge/lessons.md` and apply relevant UI lessons. After verification, follow the improvement loop in `docs/AI_AGENTS.md`.

## Implementation guidance

- Prefer the project's existing Forui, typography, color, spacing, dialog, form, menu, and feedback components.
- Use `GoogleFonts`, `FlutterSvg`, cached media, and Lucide icons only through patterns already present in the project.
- Make layouts usable on compact phones, large phones, tablets, and constrained desktop or web widths when the target screen supports them.
- Account for keyboard insets, safe areas, text scaling, long localized text, loading, empty, error, disabled, and destructive states.
- Keep touch targets accessible and give icon-only actions semantic labels or tooltips.
- Avoid duplicating business state in local widget state; connect to the existing Cubit or BLoC boundary.
- Keep animation purposeful, interruptible, and inexpensive. Respect reduced-motion behavior when applicable.

## Verification

Format changed files, run `flutter analyze`, and run focused widget or golden tests for important layout and interaction changes. Update goldens only when the visual change is intentional, and state that explicitly.
