# Code Taste

Principles of engineering judgment applied to everyday code decisions.
Each section: principle, bad example (2/5), good example (4/5), and why it matters.

---

## 1. Naming

**Principle:** Name length should be inversely proportional to scope size. A loop index lives for three lines -- `i` is fine. A public API function lives forever -- it needs a name that carries meaning without context.

Avoid "name fog": names that sound active but say nothing. `handleData`, `processInput`, `utils.ts`, `doStuff`, `manager`. If you can append the name to any function in your codebase and it still makes sense, the name is useless.

For naming as *domain language* (implementation language vs domain language, API naming), see `communication-taste.md` § Naming Things.

**Dimension boundary:** Code covers naming mechanics — scope-proportional length, name fog, file naming, casing consistency. If the same naming issue also has a domain-language problem (using implementation terms instead of domain terms), score it under Communication instead, not both.

### 2/5 -- Bad taste

```js
// What does this process? What kind of data? What does "handle" mean here?
function handleData(d) {
  const res = processInput(d.val);
  const out = transformResult(res);
  return formatOutput(out);
}

// File: utils.ts (a junk drawer that grows forever)
export function process(x) { ... }
export function convert(y) { ... }
export function format(z) { ... }
```

### 4/5 -- Good taste

```js
// The name tells you: what entity, what action, what context
function buildInvoicePdf(lineItems) {
  const subtotals = sumByTaxRate(lineItems);
  const layout = renderInvoiceLayout(subtotals);
  return exportAsPdf(layout);
}

// File: invoice-pdf.ts (one concept, discoverable)
```

**Why this matters:** You read code 10x more than you write it. Every vague name forces the reader to open the function body to understand it. Multiply that by hundreds of call sites and you get a codebase where nobody can navigate by names alone -- they navigate by grep and memory. Good names are a compression algorithm for intent.

---

## 2. Function Design

**Principle:** The "newspaper test" -- a reader should get the gist from the headline (function name and signature), the lede (first few lines), and only dive into body paragraphs (helper functions) if they need detail.

Single responsibility at the RIGHT granularity. Too fine and you get "premature extraction" -- dozens of tiny functions that only have one call site and force the reader to jump around. Too coarse and you get god functions. The test: can you name the function without using "and"?

### 2/5 -- Bad taste

```python
# Premature extraction: every 2-line operation in its own function
def get_user(id):
    return validate_user_id(id)  # just calls int(id)

def validate_user_id(id):
    return ensure_positive(int(id))

def ensure_positive(n):
    if n <= 0: raise ValueError()
    return n

# OR the opposite: god function
def handle_request(req):
    # validate input        (lines 1-40)
    # query database        (lines 41-95)
    # transform results     (lines 96-140)
    # format response       (lines 141-180)
    # send notifications    (lines 181-220)
    # update audit log      (lines 221-260)
```

### 4/5 -- Good taste

```python
def create_order(cart, customer):
    """Validate, persist, and confirm a new order."""
    validated = validate_order(cart, customer)
    order = persist_order(validated)
    send_confirmation(order, customer)
    return order

# Each helper is a meaningful unit with its own reason to exist.
# If validate_order is 8 lines, it stays inline until it has
# a second caller or its own error-handling needs.
```

**When to extract:** (1) The block has a second caller. (2) The block needs its own error handling. (3) The block is testable in isolation and you actually want that test. (4) Extracting it makes the parent function fit on one screen. If none apply, inline is better.

**Why this matters:** Premature extraction creates "function hopscotch" -- the reader bounces through a chain of single-use wrappers, losing the thread. God functions overwhelm working memory. Good granularity means each function holds one idea you can name.

---

## 3. Error Handling

**Principle:** Errors-as-values vs exceptions is context-dependent. Exceptions suit truly exceptional, don't-know-how-to-recover situations. Return values suit expected failures (file not found, validation failed, network timeout) where the caller has a reasonable response. The code-level question is: does the error handling structure make recovery paths clear and failure modes visible?

For error *message writing* (what to say, user-facing vs developer-facing), see `communication-taste.md` § Error Messages.

### 2/5 -- Bad taste

```js
// Catch-all that hides which step failed
try {
  const data = fetchAll();
  const parsed = parse(data);
  const saved = save(parsed);
} catch (e) {
  console.log("error");  // which step failed? what was the input?
}

// Swallowing errors silently
try { riskyOperation(); } catch (e) { /* ignore */ }

// Using exceptions for expected control flow
function findUser(id) {
  try {
    return db.query(`SELECT * FROM users WHERE id = ${id}`);
  } catch (e) {
    return null;  // not-found is expected, not exceptional
  }
}
```

### 4/5 -- Good taste

```js
// Each failure point handled at the right granularity
function loadConfig(path) {
  const raw = readFile(path);
  if (!raw) {
    throw new ConfigError(
      `Config file not found at ${path}. ` +
      `Working directory: ${process.cwd()}. ` +
      `Set CONFIG_PATH or create a default config with: init --config`
    );
  }
  const parsed = JSON.parse(raw);
  if (!parsed.version) {
    throw new ConfigError(
      `Config at ${path} missing required "version" field. ` +
      `See https://docs.example.com/config for the schema.`
    );
  }
  return parsed;
}

// Expected failures as return values
function findUser(id) {
  const user = db.queryOne(`SELECT * FROM users WHERE id = $1`, [id]);
  return user ?? null;  // not-found is a normal result, not an exception
}
```

**Why this matters:** Error handling structure determines whether failures are visible, recoverable, and debuggable. Swallowed errors hide bugs. Catch-alls erase context. Using exceptions for expected cases makes the happy path indistinguishable from the sad path. Good error handling makes the reader immediately see: what can fail, what happens when it does, and who is responsible for recovery.

---

## 4. Cognitive Load

**Principle:** The reader's working memory holds roughly 4 items at once (Sweller's cognitive load theory). Every level of nesting, every boolean condition, every implicit dependency consumes a slot. Code with taste respects this budget.

Rules of thumb: nesting depth of 3 or less. Boolean expressions with 3 or fewer terms. Guard clauses to flatten structure. If you need a comment to explain WHAT the code does, the code itself lacks taste. Comments should explain WHY -- the business reason, the non-obvious constraint, the historical context.

### 2/5 -- Bad taste

```python
def process_order(order):
    if order:
        if order.items:
            if order.customer:
                if order.customer.verified:
                    if not order.expired:
                        # actual logic buried at indent level 5
                        total = sum(i.price for i in order.items)
                        if total > 0:
                            charge(order.customer, total)

# Boolean fog
if (a and not b) or (c and d and not e) or (f and g):
    do_thing()

# Comment explaining WHAT (the code should say this itself)
# increment counter by one
counter = counter + 1
```

### 4/5 -- Good taste

```python
def process_order(order):
    if not order or not order.items:
        return None
    if not order.customer or not order.customer.verified:
        raise InvalidOrderError("Customer must be verified")
    if order.expired:
        raise InvalidOrderError("Order has expired")

    total = sum(item.price for item in order.items)
    if total <= 0:
        return None

    charge(order.customer, total)

# Extract complex booleans into a named concept
is_eligible = has_active_subscription(user) and within_quota(user)
if is_eligible:
    grant_access(user)

# Comment explaining WHY (not obvious from the code)
# Retry with backoff because the payment gateway returns 429
# under burst traffic but succeeds within 3 attempts.
charge_with_retry(order.customer, total)
```

**Temporal coupling** -- when code must execute in a specific order but nothing in the structure enforces it -- is a subtle cognitive load trap. If `init()` must be called before `run()`, make `run()` take the init result as a parameter, not a side effect.

**Why this matters:** Code that fits in your head is code you can reason about, debug, and modify without introducing bugs. High cognitive load doesn't mean the author is smart -- it means the author didn't do the work to simplify.

---

## 5. Consistency

**Principle:** Consistency operates at three levels: within a file, across a codebase, with community conventions. Violations at each level have increasing cost. Within-file inconsistency is confusing. Cross-codebase inconsistency is expensive. Breaking community conventions makes onboarding painful.

### 2/5 -- Bad taste

```python
# Three styles in one file
def getUser(id):        # camelCase
    pass

def update_user(id):    # snake_case
    pass

def DeleteUser(id):     # PascalCase
    pass

# Mixing patterns across a codebase:
# - src/api/ uses callbacks
# - src/services/ uses promises
# - src/utils/ uses async/await
# No documented reason for the differences.
```

### 4/5 -- Good taste

```python
# One convention, everywhere in the Python codebase
def get_user(user_id):
    pass

def update_user(user_id):
    pass

def delete_user(user_id):
    pass

# When breaking consistency deliberately, say why:

def get_user_uncached(user_id):
    """Bypass cache. Used only in admin audit flows where we need
    the true DB state. Everywhere else, use get_user()."""
    pass
```

**When to break consistency:** Almost never. Valid reasons: (1) The convention causes a measurable problem (performance, safety). (2) You're migrating incrementally -- old code uses one style, new code uses another, and there's a plan to converge. (3) A community standard changed and you're adopting the new one going forward.

Always document WHY you're deviating. Undocumented inconsistency looks like carelessness. Documented inconsistency looks like engineering judgment.

**Why this matters:** Consistency is a force multiplier for readability. When patterns are predictable, the reader spends zero cognitive load on style and all of it on logic. Inconsistency creates micro-decisions ("which pattern does this module use?") hundreds of times a day.

---

## 6. Dependencies

**Principle:** Every dependency is a trade. You get someone else's solution to a problem. You pay with: supply chain risk, upgrade burden, transitive bloat, API surface you don't control, and behavior you may not understand. A dependency you don't understand is a liability, not a feature.

### 2/5 -- Bad taste

```json
// package.json with 47 dependencies for a CLI tool
{
  "dependencies": {
    "left-pad": "^1.0.0",
    "is-odd": "^3.0.0",
    "is-even": "^1.0.0",
    "is-number": "^7.0.0",
    "lodash": "^4.17.0",       // used for _.get() once
    "moment": "^2.29.0",        // used for one date format
    "express": "^4.18.0",       // this is a CLI tool
    "chalk": "^5.0.0",
    "ora": "^6.0.0",
    "boxen": "^7.0.0",
    "gradient-string": "^2.0.0" // "it looks cool"
  }
}
```

### 4/5 -- Good taste

```json
// Intentional, justified dependencies
{
  "dependencies": {
    "esbuild": "^0.19.0",       // core build step, no alternative at this speed
    "chokidar": "^3.5.0"        // fs.watch is broken cross-platform, this is the fix
  }
}
// is-odd? It's `n % 2 !== 0`.
// lodash.get? It's optional chaining: obj?.a?.b
// moment? It's Intl.DateTimeFormat or the 3-line helper in src/dates.ts.
```

**Decision framework:**
- **Vendor** when the library is critical, unmaintained, or you need a frozen version (e.g., security-sensitive code).
- **Rewrite** when the functionality is small (< 50 lines) and well-understood. You'll understand it, you'll own it, and you won't inherit their bugs or breaking changes.
- **Accept the dependency** when: (1) the problem is genuinely hard (crypto, compression, parsers), (2) the library is well-maintained and widely used, (3) you've read the source and understand what it does.

**Why this matters:** Dependencies are the number one vector for supply chain attacks, the number one cause of "works on my machine" failures, and the number one source of mysterious breaking changes after upgrades. Every dependency should survive the question: "Is this worth the cost?"

---

## 7. Testing Taste

**Principle:** Good tests document intent. They answer "what should this system do?" not "what does the implementation look like?" Tests coupled to implementation details break on every refactor and teach you nothing when they fail. Tests coupled to behavior survive refactors and scream when something actually goes wrong.

Test names are documentation. A failing test name should tell you what broke without reading the test body.

### 2/5 -- Bad taste

```python
# Testing implementation details
def test_user_service():
    svc = UserService()
    svc.create("alice")
    assert svc._users == {"alice": {"name": "alice", "created": True}}
    assert svc._cache._store == {"alice": True}
    assert svc._db.query_count == 1

# Meaningless test name
def test1():
    assert add(1, 2) == 3

# Testing the framework, not your code
def test_json_parse():
    assert json.loads('{"a": 1}') == {"a": 1}

# Brittle snapshot of an entire object
def test_order():
    assert order.to_dict() == {
        "id": "abc-123", "status": "pending", "items": [...],
        "created_at": "2025-01-01T00:00:00Z", ...  # 40 more fields
    }
```

### 4/5 -- Good taste

```python
# Testing behavior and intent
def test_new_user_receives_welcome_email():
    svc = UserService(mailer=FakeMailer())
    svc.create("alice")
    assert svc.mailer.last_sent_to == "alice"
    assert "welcome" in svc.mailer.last_subject.lower()

def test_duplicate_username_is_rejected():
    svc = UserService()
    svc.create("alice")
    with pytest.raises(DuplicateUserError):
        svc.create("alice")

def test_expired_order_cannot_be_charged():
    order = Order(items=[item("Widget", 9.99)], expires=yesterday())
    with pytest.raises(OrderExpiredError):
        order.charge()
```

**The right abstraction level in tests:**
- **Too low:** Assert internal state, mock every collaborator, test private methods. Breaks on any refactor.
- **Too high:** End-to-end test that boots the whole system for a unit of logic. Slow, flaky, hard to diagnose.
- **Right level:** Test the public contract of the unit. Use real collaborators when cheap, fakes when expensive (network, disk, time).

**Test names as documentation:** If a teammate reads only your test names (not bodies), they should understand what the system does and what edge cases you've handled. `test_user_service` tells you nothing. `test_expired_trial_user_cannot_access_premium_features` tells you a business rule.

**Why this matters:** A test suite with bad taste is worse than no tests -- it gives false confidence, breaks constantly, and teaches the team to ignore failures. A test suite with good taste is living documentation that catches real regressions and makes refactoring safe.

---

## Summary

Code taste is not about cleverness or personal style. It is about reducing the cost of change for the next person -- who is usually you, six months from now, with no memory of why you wrote it this way.

The common thread across all seven principles:

1. **Naming** -- reduce the cost of reading
2. **Function design** -- reduce the cost of navigating
3. **Error handling** -- reduce the cost of debugging
4. **Cognitive load** -- reduce the cost of understanding
5. **Consistency** -- reduce the cost of predicting
6. **Dependencies** -- reduce the cost of maintaining
7. **Testing** -- reduce the cost of changing

Taste is the habit of asking: "Will this choice make the codebase easier or harder to work with tomorrow?" Repeatedly choosing "easier" is what separates a 4/5 from a 2/5.
