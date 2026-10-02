---
name: taste
description: >
  Use this skill when the user wants a qualitative judgment on whether
  code, architecture, APIs, or design are *good* — not just working.
  MUST USE for: the word "taste" or "品味"; phrases like "well-designed",
  "feels off", "feels mediocre", "amateur hour", "something is off",
  "design quality"; asking which approach shows better craftsmanship;
  requesting someone to evaluate overall quality of code or a system.
  Also use when the user's core question is "is this good?" rather than
  "make this work." Do NOT use for: specific bug fixes, performance
  debugging, security audits, writing tests, refactoring with clear
  instructions, or UI changes with concrete goals like "fix spacing on
  mobile."
---

# Taste

Taste is cultivated judgment about what to build, how to build it well, and which choices matter. It is not subjective preference — it is reasoned judgment that can be articulated and defended. Good taste makes things feel inevitable in hindsight.

---

## When to Trigger

**Always trigger:**
The user references engineering taste directly: "taste", "品味", "/taste", "quality judgment" — in the context of code, design, or engineering quality. Non-engineering uses of the word "taste" (food, colloquial "I don't have the taste for debugging") do not trigger.

**Trigger:**
The user asks for holistic quality judgment with no specific fix target:
- "is this good", "feels off", "feels wrong", "something is off", "overengineered", "amateur"
- The key test: the user hasn't specified *what* to fix — they're asking about overall quality

**Trigger only with explicit taste language:**
A functional request paired with the word "taste" or an unambiguous quality-judgment goal: "build X with good taste", "review the design quality of Y". Generic modifiers like "polished", "clean", "better" in a functional request ("make this more polished", "which approach is better for caching") do NOT trigger — those are normal implementation requests with a preference, not taste judgment requests. Standalone "which is better" without taste/quality language is a functional comparison, not a taste request.

**Do not trigger:**
The user has a specific functional goal with no quality signal: fix bug, optimize performance, add error handling, implement feature X, review for security.

---

## Response Depth

Every taste request gets one of two depths. Default to quick judgment. Escalate to deep review only when warranted. Explicit user depth requests always override automatic triggers — if the user asks for "quick take" on 5 files, give a quick judgment.

### Quick Judgment (default)

Use for: single files, short snippets, simple "is this good" questions, judgment-oriented comparisons, most taste requests.

Respond with natural prose:
- **Verdict** — what's good, what's off, and why
- **Highest-leverage fix** — the single change that would improve taste the most
- No scoring required. If a dimension score adds clarity, include it. Otherwise, skip.

### Deep Review

Use when ANY of:
- Target spans ≥ 3 files or is a substantial codebase section
- Target is an architecture document or PRD
- User explicitly requests "deep review", "full review", or "detailed review"

Respond with:
- Dimension-by-dimension findings for each dimension with direct evidence
- Scores (1-5) per dimension — optional, include only when they add signal beyond the prose
- Key tension — only if a real cross-dimension tradeoff exists (one decision causing opposing effects). Do not force this section.
- Recommended next move

No mandatory template. Structure the review to match what the evidence supports. Preferred output order: verdict first, evidence second, structure only as needed.

### Guide (taste-informed generation or refactoring)

When the user wants to generate or refactor code with taste (contains implementation/transformation verb + quality goal), apply reference principles during generation. For complex generation (new module/service/page), optionally spawn the advisor agent for pre-generation guidance.

For UI code, don't stop at Code and Communication taste — check Product taste too: error states, loading states, empty states, form semantics, accessibility. These are the edge cases that separate considered work from a prototype (see `references/product-taste.md` § Edge Cases as Features).

After generation, append brief **Key choices** (2-4 lines) explaining the taste decisions made — only when the choices are non-obvious.

### Compare (approach comparison)

When the user asks for a judgment-oriented comparison ("which has better taste", "which design is more considered"), analyze tradeoffs per dimension. Reference underlying principles. Label what is taste judgment vs objective advantage. When it's genuinely a matter of preference, say so. For large comparisons (many files per approach), use Deep Review's dimension-by-dimension structure within the comparison.

Ordinary implementation tradeoff questions (caching strategy, DB choice, framework selection) without explicit taste/quality intent stay outside this skill.

---

## Five Taste Dimensions

Each dimension has a full reference file in `references/`. Read the relevant ones before reviewing or generating.

| Dimension | Core tension | Ultimate test |
|-----------|-------------|---------------|
| **Code** | Consistency > cleverness | Can a tired engineer at 2am understand this? |
| **Architecture** | Resilience > elegance | Will this survive the next 3 requirement changes? |
| **Product** | Composability > completeness | Does removing this make the product better, or just easier to build? |
| **Design** | Intentionality > decoration | Does every pixel earn its place? |
| **Communication** | Teaching > describing | Can a newcomer understand the intent without asking? |

### Dimension boundaries

- **Code** covers: structure, abstraction, control flow, error handling, naming mechanics (scope-proportional length, name fog, file naming)
- **Communication** covers: naming as domain language, API surface design, documentation, commit messages, error messages
- **Overlap rule**: naming issues that are purely mechanical (vague names, inconsistent casing) count under Code. Naming issues that are about domain modeling (implementation language vs domain language) count under Communication. When a mechanical issue occurs within an API surface (e.g., inconsistent endpoint casing), score it under Communication — the API surface is Communication's domain. Do not penalize the same issue under both dimensions.
- **Comments rule**: inline code comments that explain WHY (business reasons, non-obvious constraints) are scored under Communication (documentation quality). The absence of needed comments that increases cognitive load is scored under Code (cognitive load). Do not penalize the same comment issue under both.

### Scoring scale (1-5)

- **1** = Harmful — creates confusion, tech debt, or user frustration
- **2** = Careless — works but shows no judgment about tradeoffs
- **3** = Competent — reasonable choices, nothing stands out as wrong
- **4** = Considered — clear evidence of intentional tradeoffs, good instincts
- **5** = Masterful — feels inevitable, teaches by example, would cite as reference

### Evidence rules

- Score only dimensions with direct evidence in the provided artifacts
- Skip dimensions without evidence — note briefly what's missing: "Design not reviewed — no UI artifacts provided"
- When evidence is thin (e.g., one screenshot, no interaction states): restrict scores to 2-4, mark uncertainty, give directional suggestions only
- Never assign 1 or 5 from surface-level evidence

---

## Codebase Adaptation (generation)

Before generating, extract existing patterns from the codebase:

1. Find same-type reference files (≤3) in the target directory
2. Extract: naming conventions, file structure patterns, library/framework patterns
3. Align generation with existing patterns. When existing patterns conflict with reference principles, prefer existing patterns unless they're actively harmful.

If no existing patterns are found, note: "No existing code patterns detected — recommendations based on general taste principles."

---

## Intellectual Sources

These traditions inform the taste principles. Reference them naturally when explaining judgments.

- **Unix Philosophy** (McIlroy): Do one thing well. Compose.
- **Dieter Rams** (10 Principles): Good design is as little design as possible.
- **Paul Graham** (Taste for Makers): Simplicity. Timelessness. Solving the right problem.
- **Cognitive Load Theory** (Sweller): Working memory has ~4 slots. Every unnecessary concept costs.
- **Christopher Alexander** (Pattern Language): Recurring solutions to recurring problems in context.
- **Steve Krug** (Don't Make Me Think): Interface taste = zero hesitation.
- **Rich Hickey** (Simple Made Easy): Simple is not easy. Complecting is the enemy.
- **Sandi Metz** (Practical OO Design): Prefer duplication over the wrong abstraction.
- **Kent Beck**: Make the change easy, then make the easy change.
- **Linus Torvalds** (Good Taste): Eliminate special cases. Trust upstream data.

---

## Anti-patterns (Calibration)

What bad taste looks like — use these to calibrate your judgment:

- **Astronaut architecture** — abstraction for abstraction's sake, layers with no purpose
- **Cleverness theater** — code that shows off rather than communicates
- **Premature consistency** — forcing uniformity before understanding the domain
- **Design default traps** — default padding, generic cards, no visual hierarchy, AI-generated sameness
- **Name fog** — `handleData`, `processInput`, `utils.ts`, `helpers.js`
- **Feature creep disguised as completeness** — "while we're at it" additions
- **The wrong abstraction** — DRY applied where concepts are actually different
- **Cargo cult patterns** — using patterns because "that's how it's done" without understanding why
- **Gold-plating** — polishing what doesn't matter while ignoring what does

---

## Agent Routing

Agents are optional. Most taste requests do not need them.

**Reviewer agent** (`agents/reviewer.md`) — spawn when ANY of:
- Deep review target spans ≥ 5 files
- User explicitly requests "deep review" or "full review" on a target spanning ≥ 3 files

**Advisor agent** (`agents/advisor.md`) — spawn only when:
- Generating a new module, service, or page (substantial greenfield)
- Not needed for small generation tasks (add a component, fix with taste, etc.)

The main skill owns all decisions. Agents are executors that return findings for you to synthesize.
