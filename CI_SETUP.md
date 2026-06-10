# CI Quality Gate — Setup & Handoff (Build 95)

Replaces the old fakeable "comment-string dual-agent approval" with a **real** CI
gate + GitHub Copilot review + native auto-merge. No Claude/Haiku CI job, no API key.

## Workflows
| File | Role |
|------|------|
| `pr-quality-gate.yml` | **Required gate.** `flutter analyze --no-fatal-infos` + `flutter test` + version-integrity (integer versionCode; no duplicate release tag). Runs on the real head SHA; resets every push. |
| `auto-merge.yml` | Enables GitHub **native** squash auto-merge; PR merges itself once the required gate is green. |
| `build_apk.yml` (unchanged) | On push to main, builds + releases **only on success** → a broken build never ships; the last good APK stays "latest". |
| `.github/copilot-instructions.md` | Makes Copilot's PR review app-aware (personalization, formulas, versionCode rules, security, no-bypass). |

Deleted: `check-agent-approvals.yml`, `auto-merge-on-approval.yml` (fakeable).

Code review = **GitHub Copilot** (advisory, free with your Student pack). It posts
comments; it does **not** gate the merge — the tests do. That's intentional: an LLM
opinion shouldn't hard-block a legitimate change.

---

## ⚠️ Manual steps (one-time)

### 1. Enable native auto-merge  ← required for auto-merge.yml
Settings → General → Pull Requests → check **"Allow auto-merge"**. *(Already enabled.)*

### 1b. Add `RELEASE_PAT` so auto-merge also triggers the release build
The bot merging via the default `GITHUB_TOKEN` does **not** trigger `build_apk.yml`
(GitHub anti-recursion), so the APK wouldn't auto-build. Fix: merge *as you*.
1. Create a **fine-grained PAT** (github.com → Settings → Developer settings →
   Fine-grained tokens), scoped to **this repo only**, with permissions:
   **Contents: Read/Write**, **Pull requests: Read/Write**, **Actions: Read/Write**.
2. Add it as repo secret **`RELEASE_PAT`** (Settings → Secrets and variables → Actions).

Until this is set, `auto-merge.yml` falls back to `GITHUB_TOKEN` (merges still work,
but you'll dispatch the release build manually as we did for build-95).

### 2. Make sure Copilot code review is on (optional but recommended)
Settings → Copilot / Code review (or a Ruleset) → enable automatic Copilot review on
PRs. It will read `.github/copilot-instructions.md` automatically.

### 3. Branch protection — already updated
Required status check on `main` is now **`Verify (analyze + test)`** (the old
`dual-agent-approval` was removed). Keep "Require branches to be up to date" and
"Do not allow bypassing" ON. **Never disable branch protection** (Rule 0).

---

## Why this "keeps the latest APK good"
- `verify` blocks merges that fail analyze/tests or carry a bad versionCode.
- The classic "can't install" bug (decimal/duplicate versionCode) is caught **before**
  merge by the version-integrity step.
- Even if something native slips through, `build_apk.yml` releases **only on a
  successful build**, so the newest *downloadable* release is always a good one.

## HuggingFace token (Build 104) — hardcoded in the app (no secret)
By choice, the gated-model HF token is **hardcoded** in
`lib/services/on_device_ai_service.dart` (`_enterpriseToken`, tagged `// gate-allow-token`
so the CI secret-scan allows that one line). No GitHub secret is used.

⚠️ **The currently committed token returns 401 (dead).** Whether hardcoded or in a
secret, the on-device AI model **cannot be downloaded on fresh installs** until the
constant is replaced with a **valid** token:
1. On a HuggingFace account, open `litert-community/Gemma3-1B-IT` and **accept the
   licence** (the model is gated).
2. Create an HF access token (read) on that account.
3. Replace the `_enterpriseToken` string in `on_device_ai_service.dart` with it.

To add a new intentional bundled credential later, tag its line `// gate-allow-token`.
