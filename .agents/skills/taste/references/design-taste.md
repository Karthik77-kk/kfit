# Design / UI Taste

Taste in design is the ability to make visual decisions that serve the user's goals,
not the designer's portfolio. Good design taste is invisible — users accomplish what
they came to do without noticing the interface. Bad taste draws attention to itself.

---

## 1. Visual Hierarchy

**Principle:** Every screen has one primary action and one primary piece of information.
The visual hierarchy must make both immediately obvious. If everything is bold, nothing
is bold.

**Bad taste:**
- Every element competing for attention at the same size and weight
- Using color, bold, and large type simultaneously on the same element
- Burying the primary action below the fold or in a sea of equal-weight buttons
- Three different "important" callout banners on one page

**Good taste:**
- One dominant element per view — a headline, a CTA, a key metric
- Supporting content visually recedes through smaller size, lighter weight, muted color
- Position reinforces importance: top-left for reading cultures, center for focus states
- No more than 3 levels of hierarchy on any single screen

**Why:** Visual hierarchy is information architecture made visible. When you fail to
prioritize visually, you force users to read everything to find what matters. That is
a design failure, not a user failure. Squint at your screen — if you cannot tell what
is most important from 6 feet away, your hierarchy is broken.

---

## 2. Typography

**Principle:** Typography is the primary interface material. Get it right and the design
is 80% done. Get it wrong and no amount of color or imagery saves it.

**Bad taste:**
- More than 2 typefaces in one product (3 is almost never justified)
- Body text with line-height below 1.3 or above 1.8
- Lines exceeding 80 characters — walls of text that exhaust the eye
- Decorative fonts for UI text (save them for marketing pages, if ever)
- Font sizes below 14px for body text on screens

**Good taste:**
- Line-height of 1.4-1.6 for body text, 1.1-1.3 for headings
- Measure (line length) of 45-75 characters for readable body text — 65 is the sweet spot
- Consider a system font stack (`-apple-system, system-ui, sans-serif`) for applications where
  speed and native feel matter — a strong default when brand typography isn't a priority.
  Custom fonts when brand expression justifies the performance cost and FOUT management
- A clear type scale with consistent ratios (1.2, 1.25, or 1.333) — not ad hoc sizes
- Font weight used structurally: regular for body, medium for labels, semibold for
  emphasis, bold used sparingly

**Why:** Users read text more than they look at anything else in your interface. Poor
typography creates subconscious friction — users feel tired but cannot articulate why.
A system font stack at 16px/1.5 with 65-character lines will outperform any fancy
typeface that is poorly set. Typography is not decoration; it is the product.

---

## 3. Spacing

**Principle:** Spacing creates relationships. Elements that are close together are
related. Elements that are far apart are separate. This is Gestalt psychology, and
violating it confuses users faster than any other mistake.

**Bad taste:**
- Inconsistent padding — 12px here, 17px there, 14px somewhere else
- Equal spacing between all elements regardless of their relationship
- Cramming elements together to "fit more on screen"
- Using margin/padding values that do not fall on any grid

**Good taste:**
- A spacing scale based on 4px or 8px: 4, 8, 12, 16, 24, 32, 48, 64
- Tighter spacing within groups, wider spacing between groups
- Optical alignment over mathematical alignment — visually centered text in buttons
  often sits 1-2px above mathematical center
- White space treated as a design element, not wasted space. A screen with generous
  white space communicates confidence. A cramped screen communicates anxiety
- Consistent spacing rhythm: if cards have 24px internal padding, all cards have 24px
  internal padding

**Why:** The 4px grid is not arbitrary constraint — it ensures every spacing value is
a multiple of a common base, which creates visual rhythm even when users cannot
consciously identify why the layout feels "right." Designers who eyeball spacing
create designs that feel slightly off everywhere. Designers who use a grid create
designs that feel inevitable.

---

## 4. Color

**Principle:** Color should mean something. Every color in the palette should have a
job: primary action, success, warning, error, neutral. Decorative color is noise.

**Bad taste:**
- Using color for decoration rather than communication
- Failing WCAG AA contrast (4.5:1 for normal text, 3:1 for large text) — this is
  not optional, it is a minimum bar
- Rainbow interfaces where every section has its own color "for variety"
- Light gray text on white backgrounds because it "looks clean" — it looks unreadable
- Relying on color alone to convey meaning (red/green for pass/fail with no icon or label)

**Good taste:**
- The 60-30-10 rule: 60% dominant neutral, 30% secondary color, 10% accent
- A single primary color used consistently for interactive elements
- Semantic color: blue for links and actions, red for destructive actions, green for
  success, yellow/amber for warnings — do not break these conventions without reason
- Monochrome palettes when the content is the star. A black-and-white interface with
  one accent color is often braver and more effective than a colorful one
- Dark mode as a first-class citizen, not an inverted afterthought — dark mode needs
  its own contrast values, reduced saturation, and adjusted elevation

**Why:** Color is the most emotionally powerful tool in the visual toolkit, which means
misuse is costly. When everything is colorful, color loses its ability to direct
attention. A monochrome interface with a single blue CTA button is more effective than
a rainbow interface where the user cannot distinguish actions from decoration.

---

## 5. Motion

**Principle:** Animation should answer a question the user is asking. "Where did that
element come from?" "Where did my data go?" "Is this loading?" If the animation does
not answer a question, it is decoration and should be removed.

**Bad taste:**
- Page transitions that take 500ms+ — the user is waiting, not admiring
- Bounce effects, excessive spring physics, and playful wobbles in productivity tools
- Animation on every element mount — the screen "popcorns" as items appear one by one
- Loading spinners that animate for 80ms (you saw a flash, not a spinner)
- Parallax scrolling on content-focused pages

**Good taste:**
- 150-300ms for micro-interactions (button press, toggle, dropdown)
- 200-500ms for view transitions and layout shifts
- Easing as taste: `ease-out` (fast start, gentle stop) for elements entering the
  screen — they arrive with energy and settle in. `ease-in` (gentle start, fast end)
  for elements leaving — they accelerate away. `ease-in-out` for elements moving
  within the screen
- `prefers-reduced-motion` respected always, not as an afterthought
- Staggered animations with 30-50ms delays between items — not simultaneous, not
  comically sequential

**Why:** The human eye is wired to track motion. Every animation competes for
attention with the content the user came for. In a productivity tool, the best
animation is the one you removed. In an onboarding flow, thoughtful animation can
guide understanding. Context determines whether motion helps or hinders. When in
doubt, remove it.

---

## 6. Component Design

**Principle:** Every custom component has a maintenance cost. Use standard components
until you have a specific, articulable reason to deviate. The taste is in knowing when
that reason is real.

**Bad taste:**
- Custom date pickers that lack keyboard navigation and accessibility
- Reinventing select dropdowns because the native one "looks ugly"
- Inconsistent components — buttons that look different across pages
- Custom scrollbars that break on half the browsers
- Toggle switches for actions that are not instant (use a checkbox and save button)

**Good taste:**
- Starting from a mature component library (e.g. Radix, Headless UI, shadcn/ui — or
  whatever the project already uses) and customizing the styling, not the behavior
- Visual consistency: if primary buttons are blue with 8px border-radius in one place,
  they are blue with 8px border-radius everywhere
- Standard HTML elements when they work. A `<details>` element is better than a custom
  accordion if you do not need animation
- Custom components only when the standard one genuinely fails the use case — a color
  picker, a rich text editor, a data grid with virtualization
- One source of truth for component styles. If you change button padding, it changes
  everywhere

**Why:** The most tasteful component libraries feel invisible. Users do not admire your
custom dropdown — they just want to select an option. Every hour spent building a custom
component is an hour not spent on the problem the user actually has. Restraint is taste.

---

## 7. Responsiveness

**Principle:** Responsive design is not shrinking the desktop layout until it fits a
phone. It is rethinking what matters at each screen size and context.

**Bad taste:**
- Horizontal scrolling on mobile because a desktop layout was force-fitted
- Tiny tap targets (below 44x44px) because desktop link sizes were preserved
- Hiding critical features behind hamburger menus without considering mobile workflows
- Three-column layouts that become three stacked columns on mobile — just because they
  fit does not mean the hierarchy is right
- "Please visit the desktop version for full functionality"

**Good taste:**
- Mobile-first as a design discipline: start with the smallest screen and the most
  constrained context, then add complexity as space allows
- Touch targets of 44x44px minimum, with adequate spacing between them (8px+)
- Navigation patterns that match the device — bottom navigation on mobile, sidebar
  on desktop, not the same hamburger menu on both
- Content priority that shifts by context: on mobile, the user likely wants to act
  quickly. On desktop, they may want to compare and analyze
- Breakpoints based on content needs, not device widths. When a line of text gets
  too long or a layout gets too cramped, that is your breakpoint

**Why:** Mobile is not a second-class viewport. For most products, mobile traffic
exceeds desktop. Designing desktop-first and then cramming the result into a phone
produces layouts that are technically responsive and functionally hostile. Start with
the constraints and design your way up.

---

## 8. Common Design Default Traps

These patterns are often signs of unexamined defaults, not universal anti-patterns. They become taste problems when applied without intent — in the right context (brand pages, playful products, marketing sites), some of these are perfectly valid choices.

**Default shadows everywhere.** `box-shadow: 0 4px 6px rgba(0,0,0,0.1)` on every card,
every modal, every component. Shadows should establish elevation hierarchy — if
everything floats, nothing floats. Most elements should sit flat.

**Rounded-everything.** `border-radius: 16px` on cards, inputs, buttons, images, and
containers. Rounding should be purposeful and consistent: pill shapes for tags and
badges, moderate rounding (6-8px) for cards and buttons, no rounding for full-width
sections. If the border-radius exceeds half the element's shortest side, you have a
pill — make sure you wanted one.

**Gradient backgrounds without purpose.** Purple-to-blue hero sections that say "we are
a modern tech company." Gradients are a tool, not a default. When used intentionally
for brand expression or visual warmth, they work. When defaulted into as a substitute
for design thinking, they're noise.

**Stock illustrations.** Flat-style vector people with disproportionate limbs in
pastel colors. These are the clip art of the 2020s. If illustration does not serve
a specific explanatory purpose, remove it. Whitespace is preferable to generic art.

**Generic card layouts.** A grid of cards with image on top, title, description, and
a "Learn more" link — regardless of whether the content suits this pattern. Card
layouts are appropriate for browsable, comparable items. They are not appropriate for
sequential content, detailed comparisons, or single-focus pages.

**Blur and glassmorphism as default.** `backdrop-filter: blur(20px)` on every surface.
Frosted glass can create elegant depth cues when used selectively — but as a system-wide
default it reduces readability and costs rendering performance. Ask whether the blur
serves hierarchy or just looks modern.

**Color-as-category signifier.** The blue-to-purple gradient that has become shorthand
for "this feature uses AI." When a color choice is driven by trend rather than brand
or communication, it ages fast. Communicate what the feature does, not which category
it belongs to.

**Overly complex empty states.** A 3D illustration, a witty headline, a subtitle, and
a CTA button for a state the user will see for 2 seconds. Empty states should be
helpful, not theatrical. Tell the user what to do next and get out of the way.

**Inconsistent icon styles.** Mixing outline icons, filled icons, duotone icons, and
emoji in the same interface. Pick one icon set. Use one weight. If you need to
distinguish states (active vs inactive), use fill vs outline — not two different
icon libraries.

**Summary:** These traps share one root cause: applying defaults without questioning them.
Good taste is the practice of making visual decisions intentionally. If you cannot
articulate why a shadow, a gradient, or a rounded corner is there, ask whether it serves
communication, hierarchy, or brand expression. Default conservatively; add visual
treatment when it clearly improves one of those three.
