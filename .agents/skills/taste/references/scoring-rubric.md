## Score Descriptors by Dimension

### Code

- **1 - Harmful:** Introduces bugs, security vulnerabilities, or unmaintainable patterns that will actively cause problems for the next person who touches this code.
- **2 - Careless:** Works but ignores obvious improvements: inconsistent casing, duplicated logic, missing error handling, or no consideration for edge cases.
- **3 - Competent:** Correct and readable with reasonable structure; follows the codebase's existing conventions without introducing new problems.
- **4 - Considered:** Deliberately chosen abstractions, well-placed guard clauses, clear separation of concerns, and code structure that makes the next change obvious.
- **5 - Masterful:** Every line earns its place; the code is so clear it teaches by example, handles edge cases gracefully, and you'd reference it as a model for the team.

### Architecture

- **1 - Harmful:** Creates circular dependencies, couples unrelated concerns, or makes structural decisions that will force a rewrite within months.
- **2 - Careless:** Technically functional but ignores boundaries: business logic in controllers, shared mutable state across modules, or no clear ownership of data.
- **3 - Competent:** Reasonable module boundaries and data flow; follows established patterns in the codebase without introducing architectural debt.
- **4 - Considered:** Boundaries are drawn at genuine seams of change; dependencies point inward; the structure makes the most likely future changes easy.
- **5 - Masterful:** The architecture encodes deep understanding of the domain and its evolution; extension points exist exactly where they're needed, nowhere else.

### Product

- **1 - Harmful:** Ships something users didn't ask for, breaks existing workflows, or optimizes for a metric that conflicts with actual user value.
- **2 - Careless:** Implements the spec literally without questioning whether the spec serves the user; ignores obvious usability gaps or failure modes.
- **3 - Competent:** Delivers what was asked, handles the common cases well, and doesn't introduce user-facing regressions.
- **4 - Considered:** Anticipates user needs beyond the ticket: sensible defaults, helpful error messages, graceful degradation, and awareness of adjacent workflows.
- **5 - Masterful:** The implementation reveals insight about the problem that wasn't in the spec; users feel like the system understands what they're trying to do.

### Design

- **1 - Harmful:** Inconsistent spacing, clashing visual hierarchy, or layouts that actively mislead the user about what's interactive or important.
- **2 - Careless:** Functional but visually noisy: inconsistent margins, misaligned elements, no clear hierarchy, or default styles used without thought.
- **3 - Competent:** Follows the existing design system or conventions; consistent spacing, reasonable hierarchy, nothing jarring.
- **4 - Considered:** Intentional use of whitespace, typography, and color to guide attention; the visual structure mirrors the information structure.
- **5 - Masterful:** Every pixel serves communication; the design is so clear that users never hesitate about what to do next, and the aesthetic reinforces the brand.

### Communication

- **1 - Harmful:** Misleading domain names or API names that suggest wrong behavior, comments that contradict the code, commit messages that obscure intent, or user-facing labels that confuse.
- **2 - Careless:** Domain terms used incorrectly or generically (calling a subscription a "plan" when the domain distinguishes them), missing or boilerplate commit messages, docs that restate the obvious while omitting the non-obvious.
- **3 - Competent:** Names and messages are accurate and clear; someone new to the codebase can follow along without guessing.
- **4 - Considered:** Names encode domain concepts precisely; commit messages explain why, not what; docs anticipate the reader's likely questions.
- **5 - Masterful:** The naming and documentation form a coherent narrative; reading the code teaches you about the domain, and the changelog tells the project's story.

---

## Calibration Examples

**Example 1:** A React component that fetches data in useEffect, stores it in useState, and renders a table with inline styles and no loading or error states.
Code: 3/5 because the data fetching logic is correct and readable, but the useEffect lacks cleanup on unmount and there is no separation between fetching and rendering concerns. Design: 2/5 because inline styles bypass any design system, making visual consistency impossible to maintain. Product: 2/5 because the missing error and loading states will leave users staring at a blank screen.

**Example 2:** An API endpoint that validates input with Zod, returns RFC 7807 problem details on errors, and uses consistent naming with the rest of the API surface.
Communication: 4/5 because the error format is standardized, the naming aligns with existing endpoints, and a consumer can predict behavior without reading docs.

**Example 3:** A migration that adds a non-nullable column with a default value, runs a backfill in batches, and includes a rollback path with clear comments explaining the batch size choice.
Architecture: 4/5 because it accounts for production load and reversibility. Code: 4/5 because the batch size rationale prevents the next engineer from "optimizing" it into an outage.

**Example 4:** A CLI tool that uses single-letter flags with no long-form equivalents, outputs unstructured text, and exits 0 on failure.
Communication: 1/5 because the interface actively misleads: exit codes lie, output can't be parsed, and flags can't be guessed. Design: 2/5 because the lack of help text and discoverability makes the tool hostile to new users.

**Example 5:** A settings page that groups options by user goal rather than by data model, uses progressive disclosure to hide advanced options, and validates inline with specific fix suggestions.
Product: 5/5 because the grouping reveals deep understanding of user mental models. Design: 4/5 because progressive disclosure reduces cognitive load without hiding power.

---

## Surface Scoring Rules

When scoring with limited context (thin evidence, single screenshot, no interaction states, etc.), three rules apply:

1. **No extreme scores.** Range 2-4 only. Assigning 1 or 5 requires deep understanding of intent, history, and constraints that surface evidence cannot provide.
2. **Mark uncertainty.** Label observations `[based on limited context]` and note what additional info would change the assessment.
3. **Directional suggestions only.** Use "consider...", "worth exploring...", "this might benefit from..." — not "you should" or "this must change".

---

## Edge Cases

**Mixed quality within a single file:** Score the predominant pattern, not the best or worst fragment. If a file has 200 lines of clean, well-structured code and a 20-line function that's tangled, the score reflects the 200 lines. Note the variance explicitly: "Predominantly 4/5, with one function (lines 180-200) closer to 2/5."

**Legacy code:** Score against the conventions and tools available when the code was written, not today's standards. A jQuery component from 2014 should be evaluated by 2014 jQuery norms. However, always note modernization opportunities as separate, non-penalizing observations: "Solid for its era. If this area is being actively changed, migrating to X would be worth considering."

**Framework constraints:** When the framework or platform forces a pattern that looks tasteless in isolation (e.g., Angular's verbose decorators, Redux boilerplate, iOS delegate chains), do not penalize the author for following the framework's conventions. Note it neutrally: "The verbosity here is framework-imposed, not a taste issue. Within those constraints, this is well-organized." Only penalize when the author adds unnecessary complexity beyond what the framework requires.
