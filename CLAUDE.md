# Karthik Fitness — Claude Code Guide

## Project Overview
Personal Flutter fitness tracker for Karthik (Bangalore, India) focused on fat loss and muscle retention.
- **Platform**: Android (primary), Flutter 3.44.0, Dart SDK ≥3.2
- **Architecture**: Provider + ChangeNotifier, SharedPreferences persistence
- **State**: Single `FitnessProvider` — all app state lives here

## Key Files

| Path | Purpose |
|------|---------|
| `lib/main.dart` | App entry, theme, bottom nav |
| `lib/providers/fitness_provider.dart` | All state, persistence, computed properties |
| `lib/models/models.dart` | Data models + food database (Indian foods) |
| `lib/screens/home_screen.dart` | Dashboard — rings, charts, smart tip |
| `lib/screens/nutrition_screen.dart` | Tabbed container: Food \| Water \| Supplements |
| `lib/screens/food_screen.dart` | Food logging by meal type (embeddable) |
| `lib/screens/water_screen.dart` | Water intake tracking |
| `lib/screens/workout_screen.dart` | Workout logging, per-exercise MET calories |
| `lib/screens/stats_screen.dart` | Body data entry, 1RM calculator, weight chart |
| `lib/screens/smart_scale_screen.dart` | Smart scale body composition logging |
| `lib/screens/supplements_screen.dart` | Whey/creatine/multivitamin toggle |
| `lib/screens/history_screen.dart` | 60-day history view |
| `lib/screens/settings_screen.dart` | Goals, export/import, notifications |
| `lib/services/notification_service.dart` | flutter_local_notifications, exact alarms |

## Daily Targets (user-configurable, defaults)
- Calories: 1700 kcal · Protein: 100g · Water: 2500 mL · Steps: 8000

## User Profile Defaults
- Height: 160 cm, Age: 24, Goal weight: 70 kg, Name: Karthik

---

## ⚡ Development Workflow (MANDATORY)

### Rule 1 — Never commit directly to `master`
All changes go in a feature branch. `master` is protected — only merged via PR or fast-forward after full review.

### Rule 2 — Branch naming
```
feature/build-N-short-description    # new features
fix/build-N-short-description        # bug fixes
refactor/short-description           # refactors (no build bump)
```
Example: `feature/build-43-step-goal-settings`

### Rule 3 — One feature per branch
Keep branches focused. If adding 3 features, use 3 branches.

### Rule 4 — Bump build number before merging
Every merge to `master` that ships a new APK must bump `pubspec.yaml` version:
- `versionName` (e.g. `1.0.0`) — bump for significant releases
- `versionCode` (`+N`) — bump on EVERY merge — **MUST be a whole integer** (Android requires it)
- **New features** → next integer: `76` → `77`
- **Patches/fixes** → also next integer: `77` → `78` (do NOT use `77.1` — decimals break Android versionCode)
- The branch name and commit message can say "Build 77.1" for human readability, but pubspec must have `+78`
Current build: **80**. Next build: **81**.

### Rule 5 — Commit message format
```
Build N: short imperative summary of what changed
```
Examples:
- `Build 46: add weekly progress chart`  ← new feature
- `Build 45.1: fix CI settings.gradle.kts path`  ← patch/fix to build 45

### Rule 6 — Pre-merge checklist (Claude must do ALL before merging)
1. `flutter analyze` — zero errors, zero warnings
2. `flutter test` — all tests pass
3. **`flutter build apk --release` — MANDATORY for ANY change touching Gradle/Android files.**
   - Required when changed: `build.gradle.kts`, `settings.gradle.kts`, `pubspec.yaml` deps, `AndroidManifest.xml`, any `android/` file
   - Not required for pure Dart-only changes (provider, screens, models, tests)
   - Build must complete with `✓ Built build/app/outputs/flutter-apk/app-release.apk`
   - If it fails locally it WILL fail in CI — fix it before pushing
4. Code review — correctness, no regressions, follows conventions
5. Diff review — confirm only intended files changed
6. Bump `pubspec.yaml` version code
7. **`git push origin <branch-name>` — MANDATORY. Branch MUST exist on remote before merging.**
8. Merge to `master` → CI auto-triggers → APK built

### Rule 8 — MANDATORY: Push branch to remote before merging
**This rule cannot be skipped under any circumstances.**
- The branch MUST be pushed to GitHub (`git push origin <branch-name>`) before `git merge` is run.
- A branch that only exists locally provides no audit trail and cannot be reviewed.
- Even for a one-line hotfix, the remote push is non-negotiable.
- Correct sequence — no exceptions:
```
git push origin fix/build-N-description    # ← CANNOT SKIP THIS
git checkout master
git merge --no-ff fix/build-N-description
git push origin master
git branch -d fix/build-N-description
git push origin --delete fix/build-N-description
```

### Rule 7 — After merge
- Delete the local AND remote feature branch
- Verify GitHub Actions run succeeds
- APK artifact appears under Actions → latest run

---

## Build & Run Commands
```powershell
# Feature branch workflow
git checkout master && git pull origin master
git checkout -b feature/build-N-description

# Dev cycle
flutter pub get
flutter run                          # on connected Android device
flutter analyze                      # must be clean before merge
flutter test                         # must pass before merge

# Release
flutter build apk --release

# Merge workflow (ALL steps mandatory — Rule 8)
git add -p                                      # stage only intended changes
git commit -m "Build N: description"
git push origin feature/build-N-description     # MANDATORY — remote push before merge
git checkout master
git merge --no-ff feature/build-N-description
git push origin master                           # triggers CI
git branch -d feature/build-N-description
git push origin --delete feature/build-N-description  # delete remote branch too

# Device
adb devices
adb install build\app\outputs\flutter-apk\app-release.apk
adb logcat -s flutter
```

## Dependencies (Build 42)
- `provider` — state management
- `shared_preferences` — local persistence
- `fl_chart` — charts
- `intl` — date formatting
- `uuid` — unique IDs
- `flutter_local_notifications` — exact alarm notifications
- `pedometer` — live step counting
- `path_provider` — file export path
- `share_plus` — share export file
- `file_picker` — import JSON backup
- `cupertino_icons` — iOS-style icons

## Architecture Notes
- **No backend** — SharedPreferences only, no database, no auth
- **Data retention**: workouts 90d · body 180d · scale 365d · food/water/supps 60d
- **Food DB**: static `const List<FoodItem>` in models.dart — no network lookup
- **Goals**: user-configurable (calorie, protein, water, steps) — NOT hardcoded anymore
- **Calories**: food + supplement calories (whey=120kcal) + carb/fat estimates
- **Burn**: resting (BMR prorated) + walking (steps × MET) + workout (per-exercise MET)
- **BMR**: scale BMR takes priority over Mifflin-St Jeor if SmartScale logged
- **Pedometer**: live stream with day-baseline, midnight reset detection

## Color Palette (dark theme)
- Background: `#000000` · Card: `#1C1C1E` · Primary: `#30D158` (green)
- Secondary: `#40C8E0` (cyan) · Error: `#FF453A` · Warning: `#FF9F0A` · Muted: `#8E8E93`

## Common Patterns
```dart
// Provider in build (rebuilds on change)
final p = context.watch<FitnessProvider>();

// Provider in callbacks (no subscription)
context.read<FitnessProvider>().addFoodEntry(entry);

// SharedPreferences key format
'food_YYYY-MM-DD'   'water_YYYY-MM-DD'   'supp_YYYY-MM-DD'
'workouts'          'body_history'        'scale_history'

// Goals — use p.calorieGoal not FitnessProvider.kCalorieGoal
// kCalorieGoal is an alias kept for backward compat, prefer instance getter
```

## GitHub Actions
`.github/workflows/build_apk.yml` — triggers on push to `master` or `main`.
Builds Flutter 3.44.0 release APK, uploads as artifact (30-day retention).
