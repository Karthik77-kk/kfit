# Ship Feature Branch

Full pre-merge checklist, then merge to master and push to trigger CI.

**Usage:** `/ship` (run from inside a feature branch)

## Steps

### 1. Verify you are NOT on master
```bash
git branch --show-current
```
If output is `master` or `main`, stop and ask the user which feature branch to ship.

### 2. Run flutter analyze — must be clean
```bash
cd c:\tmp\karthik-fitness && flutter analyze
```
If there are errors or warnings, fix them before continuing. Do not proceed with a dirty analyze.

### 3. Run all tests — must pass
```bash
flutter test --reporter=compact
```
If any test fails, fix it before continuing.

### 4. Show the full diff vs master
```bash
git diff master...HEAD --stat
```
Review every changed file. Confirm only intended files are in the diff.

### 5. Check pubspec.yaml version was bumped
```bash
grep "^version:" c:\tmp\karthik-fitness\pubspec.yaml
```
The `+N` build number must be higher than the last master commit. If not bumped, bump it now and commit.

### 6. Show commit log for this branch
```bash
git log master..HEAD --oneline
```
All commit messages must follow `Build N: description` format.

### 7. Merge to master
```bash
git checkout master
git merge --no-ff feature/BRANCH_NAME -m "Build N: short description"
```

### 8. Push to trigger CI
```bash
git push origin master
```

### 9. Confirm CI triggered
Use the GitHub MCP to check the latest Actions run:
- List the most recent commits on master to confirm the merge landed
- Remind the user to check GitHub Actions for the build result

### 10. Delete the feature branch
```bash
git branch -d feature/BRANCH_NAME
```

Report: branch merged, pushed, CI triggered. Done.
