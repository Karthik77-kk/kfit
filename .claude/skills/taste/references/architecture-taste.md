# Architecture Taste

Architecture taste is the judgment about where to draw lines, what to couple, and what to keep apart. The core tension: **resilience over elegance**. The ultimate test: will this survive the next three requirement changes without a rewrite?

Good architecture feels boring. It does not impress you — it disappears. You notice it only when it is bad: when a simple feature requires coordinated changes across five services, when "just adding a field" takes a sprint, when nobody can explain where a piece of logic lives.

---

## 1. Boundaries

**Principle:** A good boundary is where the rate of change differs.

Two components that change together at the same pace for the same reasons should live together. Two components that change at different rates, for different reasons, driven by different stakeholders — that is where you draw the line. Conway's Law is not a suggestion; it is a force of nature. If your org has three teams, you will get a three-service architecture whether you planned one or not. The question is whether you fight this or use it.

**Bad taste looks like:**

- Drawing module boundaries along the org chart: "Team A owns Service A" regardless of domain coherence. The billing team owns a service that handles both invoicing and user preferences because those happened to be assigned to the same team in Q2 2023.
- Splitting a monolith into microservices where the boundary cuts through a transaction. Now you need distributed transactions or sagas for what used to be a single database call.
- Creating a `common` or `shared` package that every module depends on. This is not a boundary — it is a coupling magnet disguised as reuse.
- Boundaries that mirror the tech stack instead of the domain: a "frontend" module and a "backend" module for each feature, forcing every product change to cross the boundary.

**Good taste looks like:**

- Boundaries that follow domain seams. The order system and the inventory system change for different business reasons, at different cadences. That is a real boundary. The order validator and the order persister change together — they belong together.
- Acknowledging Conway's Law explicitly: "We have two teams, so we will have two services. Let us make sure each team owns a coherent domain, not an arbitrary slice."
- Boundaries where the public interface is narrow and stable even as internals churn. A good module boundary has a small surface area. If your module exposes 40 functions, it is not a module — it is an inside-out codebase.
- Using the "what if this team quit" test: if the team owning module X disappeared, could another team pick it up from the interface contract alone?

**Why this matters:** Bad boundaries create invisible coupling — you think you have separated concerns, but every change still ripples across the boundary. Good boundaries are where you can absorb change on one side without disturbing the other. The rate-of-change test is the most reliable heuristic because it directly measures what boundaries are supposed to provide: independent evolvability.

---

## 2. Coupling and Cohesion

**Principle:** The goal is appropriate coupling, not zero coupling.

Zero coupling means zero utility. Two systems that never interact accomplish nothing together. The question is not "are these coupled?" but "what kind of coupling is this, and is that the right kind for this relationship?" There is a hierarchy: data coupling (passing data) is healthier than stamp coupling (passing structures with unused fields) which is healthier than control coupling (passing flags that alter behavior) which is healthier than content coupling (reaching into another module's internals).

**Bad taste looks like:**

- A shared database that six services read from and write to directly. This is the most insidious form of coupling because it looks decoupled — no service calls another! — but every service is coupled to every other through schema assumptions. Change a column and watch five services break.
- Feature flags passed between modules: `processOrder(order, skipValidation=true, useNewPricing=false)`. The caller controls the callee's behavior, which means the caller must understand the callee's internals.
- A service that imports types from another service's internal package. Now both services must deploy in lockstep.
- "Decoupling" by putting a message queue between two things that always change together. You have not removed the coupling — you have added a queue to it. Now you have coupling plus eventual consistency plus a dead letter queue to monitor.

**Good taste looks like:**

- Data coupling: services exchange well-defined data contracts (events, API payloads) with only the fields the consumer needs. The producer does not know or care who consumes.
- Intentional coupling where cohesion demands it. If module A cannot function without module B, make that dependency explicit in the code (import, constructor injection) rather than hiding it behind a message bus and pretending independence.
- Shared databases replaced by explicit APIs or domain events. The database is an implementation detail of the owning service, not a public interface.
- Using the "can I replace this dependency with a stub in tests?" test. If stubbing a dependency requires understanding its implementation, the coupling is too tight.

**Why this matters:** The coupling hierarchy exists because it tracks how much one module needs to know about another's internals. Data coupling means "I know your output shape." Content coupling means "I know your implementation." When you must couple — and you must — choose the kind that requires the least internal knowledge. This preserves each module's freedom to change its internals independently.

---

## 3. Evolution

**Principle:** Design for the next three changes, not the next thirty.

Kent Beck's formulation is precise: "Make the change easy, then make the easy change." This is not "plan for everything" — it is "identify the most likely axes of change and make those cheap." Over-designing for unlikely futures is as costly as under-designing for likely ones. The trick is knowing which parts of your system are stable (change slowly, driven by deep domain truths) and which are volatile (change frequently, driven by product experiments and market shifts).

**Bad taste looks like:**

- A plugin architecture for a feature that has had one implementation for three years and no credible second one on the horizon. You paid the abstraction tax and got nothing for it.
- Hardcoding something that changes quarterly: pricing tiers embedded in switch statements, country-specific rules scattered across the codebase.
- Building "the platform" before building the first product on it. You cannot design a good abstraction without at least two concrete use cases (the Rule of Three).
- Speculative generality: `AbstractMessageProcessorFactory` when you have exactly one message type. Every layer of abstraction is a prediction about future variation. Wrong predictions are expensive.

**Good taste looks like:**

- Isolating the volatile parts behind stable interfaces. Pricing logic changes monthly? Put it behind a `PricingStrategy` interface — not because you need polymorphism, but because you need to contain the blast radius of change.
- The "three concrete examples" rule before abstracting. When you see similar code in two places, wait. When you see it the third time, you understand the pattern well enough to abstract correctly. Sandi Metz: "Duplication is far cheaper than the wrong abstraction."
- Designing seams — points where the system can be extended or modified without surgery. A seam is not a full plugin system. It is a function parameter, a configuration value, a strategy pattern. Minimal investment, maximum flexibility.
- Keeping a decision log. "We chose X because of Y. If Z changes, we should revisit." This is not documentation for its own sake — it is making the next team's decision easier.

**Why this matters:** Every design decision is a bet on the future. Betting big on uncertain futures wastes effort and creates accidental complexity. Betting small on likely futures creates options. The goal is not to predict the future — it is to make the system cheap to change in the directions that matter. If you do not know which directions matter, keep things simple and concrete until you do.

---

## 4. State Management

**Principle:** Where state lives matters more than how you manage it.

The hardest bugs, the worst scaling problems, and the ugliest code all share a root cause: unclear state ownership. It does not matter whether you use Redux, MobX, Zustand, or raw context — if three components can all write to the same piece of state and none of them clearly owns it, you have a coordination problem that no library solves.

**Bad taste looks like:**

- Global mutable state accessible from anywhere. A `globals.py` or a Redux store with 200 top-level keys that any component can read and write. The state is technically centralized but practically unmanageable because there is no ownership.
- Duplicated state: the same piece of truth stored in the database, in a cache, in a local variable, and in the frontend store. When they disagree — and they will — which one wins? Nobody knows.
- Using a database as a message queue. Polling a `status` column to coordinate between services means the database owns workflow state that no single service understands holistically.
- State scattered across environment variables, config files, database rows, and hardcoded constants with no map of which source of truth governs what.

**Good taste looks like:**

- Single owner for every piece of state. If user preferences live in the UserService, that is the only place that writes them. Everyone else reads through its API. "Who owns this data?" should have exactly one answer.
- Derived state computed, not stored. If `fullName` is always `firstName + lastName`, compute it. Do not store it. Every stored derivation is a cache, and every cache is a consistency liability.
- Explicit state machines for complex workflows. An order is not "a row with a status column" — it is a state machine with defined transitions. Making the states and transitions explicit prevents impossible state combinations: an order that is simultaneously "shipped" and "cancelled."
- Clear separation between persistent state (database), session state (in-memory, scoped to a request or user session), and derived state (computed on read). Each category has different consistency requirements and different appropriate storage mechanisms.

**Why this matters:** Shared mutable state is the root of most coordination complexity. Every piece of state you add is a piece of state you must keep consistent, reason about during debugging, and migrate during schema changes. Minimizing state — especially shared mutable state — is not minimalism for its own sake. It directly reduces the number of things that can go wrong and the number of things you must hold in your head simultaneously.

---

## 5. Failure Modes

**Principle:** "How does this fail?" is the most important taste question in architecture.

The happy path is easy. Every junior engineer can design a system that works when everything goes right. Taste in architecture is disproportionately revealed by failure handling: what happens when the database is slow, when a downstream service is down, when the network partitions, when the disk fills up, when the request rate doubles. Designing for partial failure — where some parts work and others do not — is the defining challenge of distributed systems.

**Bad taste looks like:**

- A service that retries failed requests indefinitely with no backoff. When the downstream service recovers, it is immediately crushed by the retry storm.
- No timeouts. A single slow dependency causes the entire request to hang, threads pool up, and the whole service becomes unresponsive. One slow database query takes down the API, which takes down the frontend, which takes down the mobile app.
- All-or-nothing failure: the checkout page shows a blank screen because the "recommended products" widget failed to load. The 5% feature killed the 95% feature.
- Error messages that say "Something went wrong" while logging `error: null`. No context captured, no correlation ID, no way to trace what happened.
- Catch-all exception handlers that swallow errors silently. The system appears to work but produces subtly wrong results.

**Good taste looks like:**

- Circuit breakers that trip when a dependency fails repeatedly, returning a fallback response immediately instead of waiting for timeout. The circuit breaker has three states: closed (normal), open (failing fast), half-open (testing recovery). This is not just a pattern — it is a statement about how you want failure to propagate.
- Timeouts on every external call, chosen deliberately. A 100ms timeout on the cache, a 5s timeout on the payment processor, a 30s timeout on the report generator. Each reflects the expected latency and importance of that dependency.
- Graceful degradation: the product page works without reviews, the dashboard works without real-time data (showing stale data with a timestamp), the app works offline with reduced functionality. Each feature declares its dependencies and its degraded mode.
- Bulkheading: separate thread pools or connection pools for separate concerns so that a slow dependency in one area does not exhaust resources for another. The "recommendations" service being slow should not affect checkout.
- Structured error handling with correlation IDs that trace a request across service boundaries. When something fails at 3am, the on-call engineer can reconstruct the full request path in minutes, not hours.

**Why this matters:** Distributed systems are not "systems that work" — they are "systems that partially fail, all the time." The network is unreliable, services have different SLAs, hardware degrades. Good architecture taste treats failure as a first-class design concern, not an afterthought. The question is never "will this fail?" — it is "when this fails, what happens to the user?" If you cannot answer that question for every external dependency, your architecture has a gap.

---

## 6. Scaling Taste

**Principle:** A monolith is the correct architecture until proven otherwise.

The default should be a well-structured monolith, not microservices. Microservices are a scaling strategy for organizations, not for technology. They solve the problem of "too many engineers need to deploy independently" — not "our app is slow." If you have fewer than 50 engineers, you almost certainly do not need microservices. If you have microservices anyway, you probably have a distributed monolith: all the operational complexity of microservices with none of the independence benefits.

**Bad taste looks like:**

- Starting a greenfield project with eight microservices because "that is how Netflix does it." Netflix has thousands of engineers. You have twelve. Netflix built a monolith first and split it when they had to. You are skipping the learning phase.
- The distributed monolith: services that must be deployed together, that share a database, that break when any one of them is down. You have the worst of both worlds — the complexity of distribution with the coupling of a monolith.
- Splitting a service because the code is messy. If you cannot maintain clean boundaries in a monolith, you will not maintain them across a network. You will just have messy services that are also hard to debug.
- Premature horizontal scaling. Adding load balancers and read replicas when profiling shows the bottleneck is a single unindexed query. Solving O(n^2) with more servers instead of better algorithms.
- Kubernetes for a service that handles 10 requests per second. The infrastructure complexity dwarfs the application complexity.

**Good taste looks like:**

- A well-structured monolith with clear internal module boundaries. Each module has a public API (a set of exported functions or classes) and private internals. When — if — you need to split, the module boundary becomes the service boundary. The split is mechanical, not architectural.
- Splitting only when you have a concrete operational need: this module needs to scale independently (different resource profile), this module needs to deploy independently (different release cadence), this team needs autonomy (Conway's Law again).
- The "shared nothing" test before splitting: can this new service operate if the other service is down for an hour? If not, you are not splitting — you are distributing. Reconsider.
- Vertical scaling first. A single modern server handles remarkable load. A PostgreSQL instance on good hardware handles thousands of transactions per second. Exhaust vertical scaling before introducing the complexity of horizontal distribution.
- Profiling before scaling. Measure where the bottleneck actually is. The bottleneck is almost never where you think it is.

**Why this matters:** Every network boundary you introduce adds latency, failure modes, operational complexity, and debugging difficulty. These costs are real and permanent. The benefits of splitting — independent deployment, independent scaling, team autonomy — are only valuable when you actually need them. Premature microservices are bad taste because they pay real costs for hypothetical benefits. Good taste means being honest about your actual scale, your actual team size, and your actual operational maturity.

---

## 7. Data Modeling

**Principle:** The schema IS the architecture.

Show me your database schema and I will tell you what your system does, how it fails, and where it will hurt in six months. Data outlives code — your application will be rewritten three times before the schema changes once. This makes data modeling the highest-leverage architectural decision. Get the entities and relationships right and the code almost writes itself. Get them wrong and no amount of clever application code can compensate.

**Bad taste looks like:**

- A `type` column with string values that encode business logic: `if order.type == "subscription"` scattered across 30 files. The schema does not model the domain — it punts the modeling to application code.
- JSON columns used to avoid schema design. A `metadata JSONB` column that grows to contain 40 different keys with no validation, no documentation, and no migration path. You traded schema discipline for query hell.
- Denormalization as a default. Storing the customer's name on every order row "for performance" without measuring whether the join was actually slow. Now customer name changes require updating thousands of order rows, and you have a consistency problem.
- No migration strategy. Schema changes applied manually in production. No rollback plan. ALTER TABLE on a 500-million-row table during peak hours.
- Entity-Attribute-Value tables used as a general solution. Everything is a "property" with a "key" and a "value." You have reinvented a database inside your database, except without indexes, types, or constraints.

**Good taste looks like:**

- Normalization as the default, denormalization as a measured optimization. Start normalized — it is correct by construction. Denormalize only when you have profiling data showing a specific join is a bottleneck, and document the consistency tradeoff you are accepting.
- The schema expresses domain invariants through constraints: NOT NULL where a value is required, UNIQUE where duplicates are impossible, FOREIGN KEY where relationships must be consistent, CHECK constraints for valid ranges. Every constraint you add to the schema is a bug you will never have to fix in application code.
- Schema evolution planned from day one. Use a migration tool (Alembic, Flyway, goose, Prisma Migrate). Every migration has an up and a down. Migrations are tested in CI against production-like data. Large table alterations use online DDL or shadow table strategies.
- Enums and status fields modeled as proper types, not magic strings. A PostgreSQL enum or a reference table with a foreign key — either works. What does not work is a VARCHAR column where valid values are documented in a wiki page nobody reads.
- Temporal modeling when history matters. If you need to know what the price was when the order was placed, store it on the order. Do not rely on looking up the current price. Snapshot the data at decision points.

**Why this matters:** Data modeling is where domain understanding becomes concrete. A good schema is a precise statement about what your system believes to be true about the world. Constraints are not bureaucracy — they are executable documentation of business rules. When the schema is sloppy, business rules migrate into application code where they scatter, duplicate, and contradict. When the schema is precise, the application code becomes simpler because the impossible states are already prevented at the storage layer.

---

## Closing Heuristics

These quick tests help evaluate architecture taste in practice:

1. **The "explain it to a new hire" test.** If you cannot draw the system on a whiteboard in five minutes and have a new engineer understand where their feature goes, the architecture is too complex for your team.

2. **The "delete a service" test.** What happens if any given service disappears? If the answer is "everything breaks," you do not have a distributed system — you have a fragile monolith with network hops.

3. **The "two-pizza team" test.** Can one team (6-8 people) own a service end-to-end, from schema to deployment? If a service requires three teams to coordinate a change, the boundary is in the wrong place.

4. **The "revert" test.** How hard is it to undo a deployment? If rolling back requires coordinating five services, your architecture has coupling that your org chart denies.

5. **The "boring technology" principle.** Every team gets three innovation tokens (Dan McKinley). Spend them where they create differentiation, not on the message queue. Use Postgres. Use Redis. Use technology your team already knows how to operate at 3am.
