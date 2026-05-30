# Review Current Branch

Deep review of all changes on the current feature branch before shipping.

**Usage:** `/review-branch`

## Steps

### 1. Show branch and commits
```bash
git branch --show-current
git log master..HEAD --oneline
```

### 2. Full diff
```bash
git diff master...HEAD
```
Review every line changed. Look for:
- Unintended changes (files that shouldn't be in this branch)
- Debug code left in (print statements, TODO markers)
- Hardcoded values that should be constants
- Missing null checks on user-facing data
- UI strings inconsistent with app tone
- Direct commits to `p.calorieGoal` — must use instance getter, not kCalorieGoal

### 3. Flutter static analysis
```bash
cd c:\tmp\karthik-fitness && flutter analyze
```

### 4. DCM code metrics (skip — incompatible with Dart 3.12 until dcm updates realm_dart)

### 5. Run all tests
```bash
flutter test --reporter=expanded
```

### 6. Report findings
Provide a structured review:
- **Branch:** name + commits list
- **Files changed:** list with what changed in each
- **Intent matches diff:** yes/no + explanation
- **Bugs found:** list any correctness issues
- **Code quality:** DCM/analyze findings
- **Tests:** pass/fail count + any missing coverage
- **Verdict:** ✅ Ready to ship / ❌ Needs fixes (list what to fix)
