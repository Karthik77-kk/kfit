# Communication Taste

How you name things, design interfaces, write messages, and document decisions.
Code is read far more than it is written. Communication taste is the discipline
of making every word earn its place.

---

## Naming Things

The two hard problems in computer science are cache invalidation, naming things,
and off-by-one errors. Naming is hard because a name is a compressed explanation.
A good name makes the wrong code look wrong.

For naming *mechanics* (scope-proportional length, name fog, file naming),
see `code-taste.md` § Naming.

**Dimension boundary:** Communication covers naming as domain language — using domain terms instead of implementation terms, API naming that models the problem space. If the same naming issue is purely mechanical (vague name, inconsistent casing), score it under Code instead, not both.

### Principle

Use domain language, not implementation language. A name should describe *what*
something represents in the problem domain, not *how* it is stored or computed.

**Bad taste:**

```python
# Implementation language leaks everywhere
user_dict = get_user_hash_map(id)      # names the container, not the contents
tmp_str = format_name(user_dict)       # "tmp" and "str" are implementation details
flag = check_bool(user_dict)           # "flag" and "bool" say nothing about the domain
```

`user_dict` tells you about the container, not the contents. When you rename
the dict to a dataclass, the name lies. `flag` describes the storage type, not
the business concept. These are domain-language failures — the names model the
implementation instead of the problem space.

(Note: vague names like `data`, `result`, `process` that lack any information
are a *mechanical* naming issue — see `code-taste.md` § Naming. The distinction
here is names that actively use the wrong vocabulary, not names that use no
vocabulary at all.)

**Good taste:**

```python
# Domain language — what, not how
customer = find_customer(customer_id)
display_name = format_full_name(customer)
is_eligible_for_trial = check_trial_eligibility(customer)

# The name tells you the shape of the data
active_subscriptions = list_subscriptions(status="active")
monthly_revenue_cents = calculate_revenue(period=this_month)
```

`customer` is a domain concept. `is_eligible_for_trial` reads as a sentence and
makes the boolean obvious. `monthly_revenue_cents` tells you the unit so nobody
divides by 100 twice. Naming conventions *are* documentation — when every amount
ends in `_cents`, the convention prevents an entire class of bugs.

### Why this matters

Names are the most-read documentation in your codebase. A function is read
dozens of times for every one time it is written. Investing ten seconds to find
the right name saves hundreds of seconds of future confusion. When the name is
right, code reviews get faster, bugs get more obvious, and onboarding gets
cheaper.

**Heuristic:** If you need a comment to explain what a variable holds, the name
is wrong. Rename it until the comment is redundant.

---

## API Design

An API is a user interface for developers. Every principle of good UI design
applies: consistency, discoverability, forgiveness, least surprise. The
difference is that a bad API gets cemented into production systems and stays
wrong for years.

### Principle

Design for the caller, not the implementer. A good API makes simple things easy
and complex things possible. It should be hard to misuse.

**Bad taste:**

```
# Inconsistent resource naming
POST /api/createUser
GET  /api/get-all-users
PUT  /api/user_update/123
DELETE /api/users/remove?id=123

# Error response that helps nobody
{ "error": true, "code": 500 }

# Pagination with offset — breaks when data changes
GET /api/users?offset=40&limit=20
```

Mixed naming conventions (`createUser`, `get-all-users`, `user_update`) force
callers to memorize each endpoint individually. The error response gives a
boolean and a status code but no explanation, no request ID, no hint about what
to do. Offset-based pagination skips or duplicates records when rows are inserted
or deleted between pages.

**Good taste:**

```
# Consistent, resource-oriented naming
POST   /api/v2/users
GET    /api/v2/users
GET    /api/v2/users/{id}
PATCH  /api/v2/users/{id}
DELETE /api/v2/users/{id}

# Error response that helps
{
  "error": {
    "type": "validation_error",
    "message": "Email address is already registered.",
    "field": "email",
    "request_id": "req_8x7k2m",
    "docs": "https://api.example.com/docs/errors#validation"
  }
}

# Cursor-based pagination — stable under mutations
GET /api/v2/users?limit=20&after=cursor_abc123
```

Resources are nouns. HTTP methods are verbs. The URL structure is predictable —
if you know one endpoint, you can guess the rest. Error responses include what
happened (`validation_error`), why (`already registered`), where (`email`
field), a correlation ID (`request_id`), and a link to further help. Cursor-based
pagination is stable because the cursor encodes a position, not an offset.

### Versioning and idempotency

Version your API in the URL path (`/v2/`) or via headers, but pick one and be
consistent. Do not version individual endpoints differently.

Design mutating endpoints to be idempotent. If a client retries a `POST` because
of a network timeout, it should not create a duplicate. Use idempotency keys:

```
POST /api/v2/payments
Idempotency-Key: pay_req_abc123
```

The server stores the result keyed by the idempotency key and returns it on
retry. This turns "what if the network fails?" from the caller's problem into the
API's solved problem.

### Why this matters

An API is a contract. Breaking changes break trust. Inconsistent naming breaks
predictability. Missing error context breaks debugging. Every shortcut in API
design becomes a support ticket, a retry bug, or a migration project. The cost
of getting it right up front is a fraction of the cost of living with it wrong.

---

## Documentation

Documentation is a love letter to your future self. It is also the first
impression for every new contributor, every new team member, and every developer
evaluating your library at 11 PM on a deadline.

### Principle

Show before you tell. Lead with a working example, then explain. Use the
inverted pyramid: the most important information goes first, details follow for
those who need them.

**Bad taste:**

```markdown
# libfoo

## Architecture

libfoo uses a monadic transformer stack with contravariant functors
to achieve referential transparency across distributed boundaries.
The core abstraction is a `Kleisli[F, A, B]` where F is...

(800 words of theory)

## Installation

pip install libfoo

## Quick Start

(buried at line 200)
```

The README reads like an academic paper. A developer who just wants to solve a
problem has to wade through theory to find the install command. Architecture
docs belong in a separate file for contributors, not in the front door.

**Good taste:**

```markdown
# libfoo

Send emails in three lines:

    from libfoo import Mailer
    mailer = Mailer("smtp://localhost")
    mailer.send("hello@example.com", subject="Hi", body="It works.")

## Install

    pip install libfoo

## Why libfoo?

- Async and sync support out of the box
- Automatic retries with backoff
- Type-safe templates

## Docs

Full docs at docs.libfoo.dev — start with the [5-minute tutorial].
```

The README is a sales page. Within ten seconds, the reader knows what the library
does, how to install it, and what makes it worth choosing. Details live in
dedicated docs, not in a wall of text.

### Inline documentation

Comments should explain *why*, not *what*. The code already says what. A comment
that restates the code is noise that rots when the code changes.

```python
# Bad: restates the code
x = x + 1  # increment x

# Good: explains why
x = x + 1  # compensate for zero-indexed month in legacy API
```

### Why this matters

Nobody reads documentation linearly. People scan, skip, and search. The inverted
pyramid respects that behavior. Code examples first, theory second, edge cases
last. If your README does not show a working example in the first ten lines, most
developers have already closed the tab.

---

## Commit Messages

The diff shows *what* changed. The commit message exists to explain *why*.

### Principle

A commit message is written for the person reading `git blame` six months from
now, trying to understand why this line exists. Write for that person.

**Bad taste:**

```
fix bug
update stuff
WIP
asdf
changes
fix tests
fix tests again
ok NOW tests pass
```

These messages are write-only. They served the author in the moment and serve
nobody afterward. When someone hits `git blame` on a confusing line and finds
`fix bug`, they have learned nothing.

**Good taste:**

```
fix: prevent duplicate charges when payment webhook retries

Stripe sends webhook events at-least-once. Our handler was not
idempotent — it created a new charge record on every delivery.
Now we check for an existing charge with the same payment_intent_id
before inserting.

Fixes #1042
```

The subject line says *what* at a glance. The body says *why* this change was
needed (Stripe retries), *what was wrong* (not idempotent), and *how it was
fixed* (dedup by payment_intent_id). The issue reference connects the commit
to the broader conversation.

### Conventional commits

The `fix:`, `feat:`, `docs:` prefixes from conventional commits are useful when
they drive automation — changelogs, version bumps, release notes. They add
clarity when a team agrees on their meaning.

They become noise when applied mechanically without thought. `chore: update
dependency` on every Dependabot PR teaches your brain to skip the prefix
entirely. If the prefix does not trigger automation or aid scanning, drop it.
Substance over ceremony.

### Why this matters

Commit history is the only documentation that is guaranteed to exist for every
change. It cannot go stale because it is immutable. Investing thirty seconds in
a good commit message creates permanent, searchable context. Sloppy messages
create permanent, searchable confusion.

---

## PR Descriptions

A PR description is written for the reviewer, not the author. The author already
knows the context. The reviewer does not.

### Principle

Give reviewers what they need to evaluate the change: *why* it exists, *what*
approach was chosen (and what alternatives were rejected), and *how* to verify
it works.

**Bad taste:**

```markdown
## Changes
- Updated UserService.java
- Modified user_controller.rb
- Added migration 20240315_add_email_verified
- Fixed tests
- Updated README
```

This is a file list, not a description. The reviewer can see the file list in
the diff. This tells them nothing about intent, risk, or context.

**Good taste:**

```markdown
## Summary

Users can now verify their email before accessing paid features.
Previously we trusted the email from OAuth providers, but some
(notably GitHub with private emails) return unverified addresses.

## Approach

- Added `email_verified` column (default false, backfilled for
  existing users with confirmed OAuth emails)
- Verification flow sends a token via email, valid for 24 hours
- Gated paid feature access on `email_verified = true`

## Alternatives considered

- Reverifying on every login: too much friction, users complained
  in #998
- Trusting provider `email_verified` claim: unreliable for GitHub
  private emails

## Testing

- Unit tests for token generation and expiry
- Integration test for full verify flow
- Manual test: sign up with GitHub private email, verify, access
  paid feature
```

The reviewer now knows *why* (unverified OAuth emails), *what* (new column,
verification flow, access gate), *what else was considered* (and why it was
rejected), and *how to verify*. They can review with confidence and catch
real issues instead of asking basic context questions.

### Why this matters

Bad PR descriptions waste reviewer time. Every question a reviewer has to ask
in comments is a round-trip that costs hours. A five-minute investment in the
description prevents days of back-and-forth. It also creates a searchable
record — when someone finds this PR six months later via `git blame`, the
description explains the full decision, not just the code.

---

## Error Messages

Every error message should answer three questions: What happened. Why it
happened. What to do next.

For error handling *structure* (exceptions vs return values, catch granularity,
recovery patterns), see `code-taste.md` § Error Handling.

### Principle

An error message is a tiny piece of UI that appears at the worst possible
moment — when something has gone wrong and the user is frustrated. Respect
that moment. Be clear, specific, and actionable.

**Bad taste:**

```
Error: EPERM
Error: null
Error: Something went wrong. Please try again later.
Error: Unexpected token < in JSON at position 0
```

`EPERM` is a code, not a message. `null` is a bug masquerading as feedback.
"Something went wrong" is what you say when you have nothing useful to say.
The JSON parse error leaks an implementation detail (the server returned HTML
instead of JSON) without explaining what the user should do.

**Good taste:**

```
Could not save your document. You don't have write permission
to this folder. Move the file to your home directory or ask an
admin to grant access.

Could not connect to the database at db.internal:5432.
The connection timed out after 5 seconds. Check that the
database is running and the hostname is correct in DATABASE_URL.

Payment failed. Your card was declined by the issuer.
Try a different card or contact your bank. (ref: pay_err_8k2m)
```

Each message follows the pattern: *what happened* (could not save), *why*
(no write permission), *what to do next* (move the file or ask an admin).
The payment error includes a reference ID so support can find the exact
transaction.

### User-facing vs developer-facing

User-facing messages should never contain stack traces, class names, or raw
exception types. A stack trace is diagnostic information for developers, not
communication for users. Log the stack trace. Show the user a human sentence.

```python
# Bad: leaking internals to users
raise HTTPException(
    status_code=500,
    detail=f"NullPointerException in PaymentProcessor.charge() "
           f"at line 142: {traceback.format_exc()}"
)

# Good: separate concerns
logger.exception("Payment processing failed", extra={
    "customer_id": customer.id,
    "amount": amount,
    "trace_id": trace_id,
})
raise HTTPException(
    status_code=502,
    detail={
        "message": "Payment could not be processed. Try again in a moment.",
        "trace_id": trace_id,
    }
)
```

The developer gets the full stack trace in structured logs. The user gets a
clear message and a trace ID to reference if they contact support. Both
audiences get what they need.

### Why this matters

A good error message turns a frustrating moment into a solvable problem. A
bad error message turns a solvable problem into a support ticket. Every
`Something went wrong` costs someone time — the user searching for answers,
the support team guessing at causes, the developer reproducing from
insufficient information. Three clear sentences prevent all of that.

---

## Summary

Communication taste is the recognition that every string a developer writes —
a variable name, an endpoint path, an error message, a commit subject — is
read by a human under time pressure. Good communication taste minimizes the
time between reading and understanding. It is not about being clever or
verbose. It is about being clear, consistent, and intentional with every word.
