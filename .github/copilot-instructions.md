# Copilot Code Review Instructions — Karthik Fitness

A personal Flutter fitness tracker (Provider + ChangeNotifier + SharedPreferences,
single `FitnessProvider`). Review **only the diff**, be concise and high-signal, and
flag **real problems** — do not nitpick formatting or things `flutter analyze` covers.

Order findings by severity. For each, give the file/line and a one-line fix.

## 1. Personalization — NO static fitness numbers (highest priority)
Every number shown to the user must be derived from THEIR data, never hardcoded.
- Calorie burn, BMR, TDEE, water/protein goals, walking burn, 1RM **must scale**
  with the user's weight / height / age / sex / smart-scale stats.
- ❌ Flag: a fixed kcal/step/rep value, a hardcoded goal, a magic constant used
  where a `provider` getter exists (`bestTdee`, `bmr`, `recommendedProteinGoal`,
  `walkingCaloriesBurned`, etc.).
- Workout calories must stay `MET[exercise] × bodyWeight × duration`. Don't
  collapse per-exercise MET into one flat value.

## 2. Calculation integrity
- Don't break the formulas: Mifflin–St Jeor BMR, adaptive (energy-balance) TDEE,
  MET-based burn, Epley/Brzycki-style 1RM, BMI/FFMI/WHR.
- Guard against divide-by-zero, null weight/height, empty history lists.
- Cardio logged as sets×reps is already a known weak spot — don't make it worse.

## 3. Versioning (these bugs have shipped before — be strict)
- `pubspec.yaml` versionCode **must be a whole integer** (`2.3.0+96`), never a
  decimal (`+95.1`) — Android truncates decimals and the update won't install.
- Every shippable change bumps the integer by 1.
- The "Build N" in the commit/PR must match the pubspec `+N`.

## 4. Android identity (never change)
- Never change `applicationId` (`com.example.karthik_fitness`) — it orphans every
  user's install.
- `namespace` must match the package in committed `.kt` files. They are NOT the
  same field as `applicationId`.

## 5. Security
- No hardcoded secrets/tokens/API keys/keystores in source or committed files.
  Flag any `hf_…`, `ghp_…`, passwords, or base64 keystores added to tracked files.

## 6. CI / branch protection
- Never weaken or disable branch protection, never add a way to bypass the
  required check, never reintroduce "approve by posting a magic comment string".

## 7. Flutter / Provider conventions
- `context.watch` in `build`, `context.read` in callbacks.
- Dispose controllers/subscriptions; guard `notifyListeners()` after dispose.
- No blocking I/O or heavy work in `build()`.
- SharedPreferences day keys: `food_YYYY-MM-DD`, `water_YYYY-MM-DD`, etc.
- Null-safety: validate/`clamp` parsed JSON; default gracefully on corrupt data.

## 8. Tests
- New logic needs tests covering boundaries, zero values, and every branch.
- Tests must be deterministic — flag `DateTime.now()` used where a fixed time is
  needed (it causes time-of-day flakiness).
- A PR that adds logic but no tests should be called out — the gate enforces a
  coverage floor, so untested code can fail CI.

## 9. Production-safety red flags (the CI gate hard-fails these — call them out early)
- A hardcoded credential (`hf_…`, `ghp_…`, AWS key, private key) anywhere in `lib/`.
- Any change to `applicationId` or `namespace` away from `com.example.karthik_fitness`.
- A `pubspec.yaml` versionCode that is a decimal, unchanged, or not greater than the
  last shipped build.
- New `warning`/`error`-level analyzer issues (info-level is fine).
- A change that removes or weakens a null-guard, await, or error path on a code path
  that handles user data, parsing, or the on-device model.
