# CI Quality Gate — Setup & Handoff (Build 95)

This replaces the old fakeable "comment-string dual-agent approval" with a **real**
CI gate. Two workflows were **deleted**:

- `.github/workflows/check-agent-approvals.yml`
- `.github/workflows/auto-merge-on-approval.yml`

…and replaced by **`.github/workflows/pr-quality-gate.yml`**:

| Job | What it does | Gate role |
|-----|--------------|-----------|
| `verify` | `flutter analyze` + `flutter test` on the real head commit; `flutter build apk --release` only when Android/Gradle files change; skips heavy steps on docs-only PRs | **Hard, required, un-fakeable** |
| `claude-review` | Haiku (`claude-haiku-4-5`) reviews only the PR diff, posts inline findings | Advisory (always runs) |

---

## ⚠️ Manual steps required (Claude could not do these — no GitHub auth)

`gh` was unauthenticated during this change (`GITHUB_TOKEN` was invalid), so the
following are **yours to do**. Do them in order, or PRs will be unable to merge.

### 1. Re-authenticate `gh` with a FRESH token
The token pasted in chat is burned — **revoke it** and create a new one.
```powershell
gh auth login            # interactive, recommended
# or: set a new fine-grained PAT with repo + workflow scopes
```

### 2. Add your Claude subscription OAuth token as a repo secret
The `claude-review` job uses your **Claude Pro/Max subscription** — no paid API
billing needed. (Pro/Max ≠ Anthropic API; the developer API is billed separately
via console.anthropic.com. We avoid that by using the subscription OAuth token.)

Generate the token on a machine where you're logged into Claude Code:
```powershell
claude setup-token        # prints a long-lived OAuth token
```
Then add it as a repo secret (Settings → Secrets and variables → Actions):
- **Name:** `CLAUDE_CODE_OAUTH_TOKEN`
- **Value:** the token from `claude setup-token`

```powershell
# or, once gh is authed:
gh secret set CLAUDE_CODE_OAUTH_TOKEN
```

> If you later move to paid API billing instead, swap the secret for
> `ANTHROPIC_API_KEY` and change the matching line in `pr-quality-gate.yml`.

Note: `claude-review` is **advisory** and is **not** a required check yet, so a
missing token won't block merges. Once you've confirmed it runs, you can optionally
add `Claude review (Haiku)` to the required checks (step 3).

### 3. Update branch protection required checks  ← CRITICAL
Branch protection currently requires the **`dual-agent-approval`** status, which no
longer exists (its workflow was deleted). If you don't change this, **no PR can ever
merge.** Update the required status checks for `main`:
- ❌ Remove: `dual-agent-approval`
- ✅ Add: **`Verify (analyze + test)`** (the `verify` job's name)
- (Optional) Add `Claude review (Haiku)` if you want the review job required too.

Keep "Require branches to be up to date before merging" ON.
**Do NOT disable branch protection** (CLAUDE.md Rule 0).

### 4. Push this branch and open the PR
```powershell
git push origin feature/build-95-haiku-ci-gate
# open PR to main; the new gate runs on the PR itself
```

> Bootstrap note: because branch protection still references the old check until you
> do step 3, do step 3 **before** trying to merge this PR.

---

## Rotate the leaked HuggingFace token (separate security fix, do soon)
`lib/services/on_device_ai_service.dart` hardcodes `hf_…` in source — it ships in
every APK. Revoke it on HuggingFace and move it to a `--dart-define` build secret.
Tracked as a follow-up, not part of this PR.
