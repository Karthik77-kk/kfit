# Product Taste

Product taste is the judgment of what to build and what not to build. It is the hardest taste to develop because the feedback loop is slow — you ship, wait, and sometimes learn you were wrong six months later. Good product taste is pattern-matched from those slow loops, applied faster each time.

---

## 1. Feature Composition

**Principle:** Features should multiply each other's value, not merely add to it. Before building anything, ask: "Will users combine this with something we already have?"

**Bad taste:**
A note-taking app adds a calendar view AND a Pomodoro timer. These features sit side by side. Neither makes the other better. The calendar does not know about the timer. The timer does not know about your schedule. You have built two half-products inside one product.

**Good taste:**
Sublime Text's command palette and keyboard shortcuts. Every command accessible via the palette is also bindable to a shortcut. Learn one system, and the other becomes more powerful. The palette teaches you what shortcuts exist. The shortcuts reward you for learning what the palette showed you. One feature is the discovery mechanism for the other.

Another example: Notion's databases and page links. A database entry IS a page. Linking between them means your wiki and your structured data are the same thing. The features do not coexist — they compose.

**Why this matters:**
Additive features grow your product linearly — N features, N units of value. Composable features grow it combinatorially. But more importantly, composable features create a coherent product. Additive features create a drawer of unrelated tools. Users feel this difference even when they cannot articulate it. A product full of additive features feels busy. A product with composable features feels deep.

---

## 2. Simplicity Calculus

**Principle:** The feature you choose NOT to build is often your highest-taste decision. Simplicity is not the absence of capability — it is the discipline of restraint applied with judgment.

**Bad taste:**
A project management tool that adds time tracking, invoicing, resource planning, Gantt charts, OKR tracking, and a built-in chat. Each feature was requested by a real customer. Each feature was "easy to build." The result: a product that takes 45 minutes to onboard and where no single workflow feels considered. The team congratulates itself on feature count while users quietly migrate to a tool that does one thing well.

**Good taste:**
Things 3 is a to-do app with no collaboration, no Gantt charts, no time tracking. It manages tasks. The team said "no" to hundreds of reasonable feature requests to keep the product focused. The result: an app that feels inevitable, where every interaction has been considered. Users do not ask "where is this feature?" — they stop thinking about the tool and start thinking about their work.

Google's original search page is the canonical example. One text field. In a world where Yahoo and Excite were portals with dozens of links, news feeds, and stock tickers, Google's restraint was radical. That emptiness communicated: "We are confident in our one thing."

**Why this matters:**
Every feature you add has a cost beyond its build time: cognitive load on every user who has to understand (or ignore) it, maintenance burden on every future change, interaction surface with every other feature. The paradox of choice is real — more options cause decision paralysis and reduce satisfaction. When everything is a priority, nothing is. A product with taste says "this is what we do" and means it.

---

## 3. User Mental Model

**Principle:** The product should teach its own mental model through use. If your product requires documentation to be understood, the design has failed. Consistency of metaphor is more important than local optimization.

**Bad taste:**
Jira's configuration model. Projects have schemes. Schemes have configurations. Configurations have sub-configurations. Each layer uses different terminology ("workflow scheme" vs "issue type screen scheme" vs "field configuration scheme"). There is no unifying metaphor. Users cannot predict where a setting lives because the organizational model is not learnable — it is memorizable, and only with effort.

A settings page where some options are toggles, some are dropdowns, some require navigating to a sub-page, and one critical option is hidden in an "Advanced" section that contradicts the non-advanced version. The user cannot build a mental model because the product has no consistent model to teach.

**Good taste:**
Git's mental model: everything is a snapshot (commit), and refs (branches, tags) are just pointers to snapshots. Once you grasp this, you can predict how commands work even before learning them. `git branch` creates a pointer. `git checkout` moves where HEAD points. `git merge` creates a new snapshot with two parents. The metaphor is consistent, so users can reason about new situations.

The iPhone's home screen: apps are icons in a grid. Tap to open, press home to close. Folders are grids inside grids. The metaphor scales from one app to hundreds without changing shape.

Progressive disclosure done right: VS Code shows a clean editor by default. The sidebar reveals file management. The command palette reveals power features. The settings JSON reveals full control. Each layer is discoverable from the previous one, and each layer uses the same interaction patterns as the last.

**Why this matters:**
Users do not read your documentation. They poke at the product and build a theory of how it works. If that theory is correct — if the product's actual model matches the model a user naturally infers — the product feels intuitive. If the theory is wrong, the product feels hostile. Consistency is what makes mental models learnable. Break the metaphor once and users stop trusting their instincts. Break it twice and they stop trying.

---

## 4. Defaults

**Principle:** The default IS the product for 80% of users. Most users never change a setting. Choosing the right default is one of the highest-leverage product decisions you will make.

**Bad taste:**
A CLI tool that requires a config file before it will run. The "getting started" guide is eight steps before "hello world." The authors think they are giving users flexibility. They are actually giving users homework.

Browser notifications defaulting to "ask on every site visit." The intent was user empowerment. The result: every website immediately asks for notification permission, users learn to click "deny" reflexively, and the entire notification permission system becomes meaningless.

Data sharing defaulting to opt-out. The user must actively find and disable telemetry buried in settings. This is not a default — it is a dark pattern. It says: "We value our analytics over your trust."

**Good taste:**
VS Code's default configuration. Syntax highlighting, a file explorer, git integration, an integrated terminal — all active on first launch. No setup wizard. No mandatory configuration. You open a folder and start working. The defaults say "we know why you are here."

Auto-save. Every application should auto-save by default. The concept of "unsaved changes" is a relic of technical limitation, not a feature. When Apple made auto-save the default in macOS, some users complained. Those users were wrong. Losing work to a missed Cmd+S is never acceptable.

Stripe's API defaults. Idempotency built in. Sensible timeouts. Error messages that tell you what to do, not just what went wrong. The defaults protect you from common mistakes without requiring you to know the mistakes exist.

**Why this matters:**
Defaults reveal what you believe about your users. Good defaults say "we have thought about your situation and made a reasonable choice." Bad defaults say "here are all the options, good luck." The configuration screen is not the product. The product is what happens before the user opens the configuration screen. If your product requires configuration to be useful, you have shipped a toolkit, not a product.

---

## 5. Scope

**Principle:** Knowing what the product is NOT is more important than knowing what it is. Scope discipline is taste. Feature creep disguised as "completeness" is the most common way products lose their identity.

**Bad taste:**
Evernote's trajectory. It started as a note-taking app. Then it added a web clipper, then document scanning, then a chat feature, then a presentation mode, then a task manager, then a calendar integration. Each addition was defensible in isolation. The sum was a product that did everything adequately and nothing exceptionally. Users who wanted notes went to Bear or Apple Notes. Users who wanted tasks went to Todoist. Users who wanted a wiki went to Notion. Evernote tried to be everything and became nothing anyone specifically chose.

A developer tool that adds a built-in AI assistant, a dependency visualizer, a deployment pipeline, a monitoring dashboard, and a collaboration layer. The team calls it a "platform." Users call it bloated. Each feature is 70% as good as the dedicated tool. The product's identity becomes "it also does that, sort of."

**Good taste:**
SQLite's scope document explicitly states what SQLite is not. It is not a replacement for PostgreSQL. It is not a client-server database. It is not designed for high write concurrency. By defining what it refuses to be, SQLite has maintained its identity for over two decades. It is the most deployed database in the world precisely because it knows what it is.

Basecamp has maintained scope discipline for years. It is a project management tool for small teams. It does not try to replace Slack, Jira, or Salesforce. Feature requests that push it toward those products get a "no." The result: a product with a clear identity that attracts users who want exactly that product.

**Why this matters:**
Scope creep does not arrive as a single catastrophic decision. It arrives as a series of small, reasonable additions, each justified by customer requests or competitive pressure. No single feature kills the product. The accumulation does. The cure is a clear articulation of what the product is not — written down, referenced in planning, and used to say "no" to good ideas that do not fit. A product that tries to serve everyone ends up serving no one particularly well. Taste is the willingness to disappoint some users so you can deeply serve others.

---

## 6. Edge Cases as Features

**Principle:** Error states, empty states, and loading states are not afterthoughts — they are features. They are often the first thing a user sees, and they communicate more about your product's quality than the happy path ever will.

**Bad taste:**
A dashboard that shows "No data" when a new user signs up. The user's first experience of the product is a void. They do not know if something is broken, if they need to configure something, or if they are in the wrong place.

An error message that says "Something went wrong. Please try again later." This is not an error message — it is an admission that the team did not think about this state. The user has no idea what happened, whether their action was saved, or what "later" means.

A loading spinner with no context. Is it loading for 2 seconds or 2 minutes? Is it fetching data or processing something? The user stares at a spinning circle and wonders if the product has frozen.

**Good taste:**
Stripe's dashboard for new accounts shows a checklist of integration steps with clear progress indicators. The empty state IS the onboarding. There is no separate "getting started" flow because the empty product already guides you.

GitHub's 404 page. It is not just a status code — it is a designed experience. The parallax Star Wars scene communicates "we know you hit a dead end, but this product is made by people who care about details." It turns a failure into a brand moment.

Linear's loading states use skeleton screens that match the layout of the content being loaded. Your brain pre-processes the structure, so when data arrives, it feels instant. The loading state is not a waiting room — it is a preview.

Slack's error handling when a message fails to send: the message stays in the compose area, marked red, with a retry button. Your text is not lost. The error state preserves your work and gives you a clear action. Compare this to apps where a failed send means your message vanishes into nothing.

**Why this matters:**
The happy path is easy. Every product gets it roughly right. The edge cases are where taste becomes visible. A carefully designed empty state tells new users "we expected you and prepared for your arrival." A thoughtful error message tells users "we respect your time and will help you recover." A considered loading state tells users "we know waiting is frustrating and we are doing what we can." These states are disproportionately important because they occur at moments of vulnerability — when the user is new, confused, or when something has gone wrong. How you treat users in those moments defines your product's character.

---

## Summary

Product taste is not about adding the right features. It is about the discipline to compose features that multiply value, the restraint to leave features unbuilt, the consistency to teach a learnable mental model, the empathy to choose good defaults, the clarity to define what you are not, and the care to design for moments when things go wrong.

The through-line: taste is judgment applied in service of the user, not the roadmap.
