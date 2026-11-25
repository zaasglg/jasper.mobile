# Idea Council Protocol

## 1. Frame the case

Restate the decision as one question. Capture:

- desired user or business outcome;
- affected users;
- known evidence;
- constraints and non-negotiables;
- assumptions;
- decision horizon;
- whether the choice is reversible.

If essential information is absent, state reasonable assumptions and continue. Ask the user only when different answers would materially change the decision.

## 2. Select independent voices

Use these five perspectives:

1. **User Advocate** — user problem, usability, accessibility, trust, and adoption.
2. **Product Strategist** — outcomes, positioning, alternatives, scope, and opportunity cost.
3. **Technical Architect** — feasibility, architecture, security, reliability, maintenance, and delivery risk.
4. **Business and Growth Analyst** — value, cost, distribution, metrics, and sustainability.
5. **Skeptic and Risk Counsel** — hidden assumptions, failure modes, abuse cases, and the strongest argument against the idea.

Delegate voices as separate subagents when possible so their first opinions are independent. If fewer execution slots are available, assign multiple perspectives to one subagent but require a separate verdict for each role. The chair synthesizes and does not cast an ordinary vote.

Every voice receives the same neutral brief and returns:

- verdict: `support`, `support with conditions`, `oppose`, or `insufficient evidence`;
- the strongest reason for its verdict;
- the strongest counterargument to its own position;
- key assumption;
- primary risk;
- cheapest useful validation step;
- confidence from 0 to 100;
- scores from 1 to 5 for user value, feasibility, strategic fit, and risk-adjusted value.

## 3. Cross-examine

After first verdicts are collected, compare disagreements rather than asking everyone to repeat their case.

- Identify factual conflicts, different assumptions, and different value judgments.
- Let a voice revise its vote only when new evidence or a clearly stronger argument is introduced.
- Record vote changes and the reason. Do not pressure dissenters to create unanimity.

## 4. Count and interpret votes

A quorum requires at least three distinct perspectives.

Summarize raw votes by verdict. Also calculate each voice's average of the four 1–5 scores. Treat this as a comparison aid, not a substitute for reasoning.

Decision rules:

- Recommend proceeding when a majority supports the idea or supports it with conditions, no unresolved critical risk exists, and evidence is adequate for the size of the commitment.
- Recommend a small experiment when support exists but a decisive assumption is unverified.
- Recommend revising when the core problem is valuable but the proposed solution performs poorly.
- Recommend stopping when opposition identifies a credible fatal flaw or the opportunity is weak relative to cost.
- Return `insufficient evidence` when a responsible decision cannot be made. Name the smallest evidence-gathering step.

For a tie, prefer the option with stronger evidence and lower irreversible downside. If still tied, recommend the cheapest reversible experiment instead of inventing certainty.

## 5. Produce the shared result

Use this concise structure:

### Case

The decision, assumptions, and evidence used.

### Votes

A table with voice, verdict, confidence, average score, and decisive reason.

### Council decision

One of: `proceed`, `proceed with conditions`, `run an experiment`, `revise`, `stop`, or `insufficient evidence`.

Include the vote count and confidence level: low, medium, or high.

### Why

The two or three arguments that actually determined the result.

### Dissent

The strongest minority view and the condition under which it would become decisive. Never omit this section when there is disagreement.

### Next step

The smallest concrete next action, owner if known, success signal, and decision checkpoint. Do not implement it unless separately requested.
