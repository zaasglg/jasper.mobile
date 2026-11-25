---
name: jospar-idea-council
description: Convene multiple independent AI voices to discuss, challenge, score, and vote on a product idea, feature proposal, strategy, or architectural direction, then produce one evidence-aware recommendation with dissent preserved. Use for idea discussion and decisions, not routine implementation.
---

# Jospar Idea Council

Act as the chair of a structured multi-agent council. The goal is not forced consensus; it is a decision whose reasoning, uncertainty, and dissent are visible.

Before deliberation, read `.agents/knowledge/lessons.md`. Then read [references/council-protocol.md](references/council-protocol.md) and follow it completely.

## Operating rules

- Frame the decision, constraints, known evidence, and missing information before voting.
- Delegate to independent subagents when delegation is available. Give each voice the same neutral brief and do not reveal other votes before its first verdict.
- Use at least three voting voices. Prefer all five roles defined in the protocol when capacity permits; combine roles transparently when capacity is limited.
- Separate facts, assumptions, and opinions. Browse or inspect the repository when current evidence is necessary and the task authorizes it.
- Do not let vote count hide weak evidence. Confidence and evidence quality affect the final recommendation.
- Preserve meaningful minority objections and state what new evidence would change the result.
- Discussion does not authorize implementation, external messages, purchases, or other mutations. Stop at a recommendation unless the user separately asks for action.

After the council concludes, apply the continuous-improvement rules in `docs/AI_AGENTS.md`. Record only reusable, verified project lessons, never the council's unsupported opinions.
