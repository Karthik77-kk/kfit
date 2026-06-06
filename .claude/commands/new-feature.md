# New Feature Branch

Start a new feature branch following the project workflow rules.

**Usage:** `/new-feature build-43-add-calorie-goal-setting`

## Steps

1. Check you are on master and it is up to date:
```bash
git checkout master && git pull origin master
```

2. Create and switch to the feature branch using the argument provided:
```bash
git checkout -b feature/$ARGUMENTS
```

3. Confirm the branch was created:
```bash
git branch --show-current
```

4. Remind the user:
- Make all changes in this branch
- Run `flutter analyze` before committing
- Run `flutter test` before merging
- Bump `pubspec.yaml` versionCode (+1) before the final commit
- Commit message format: `Build N: short description`
- Use `/ship` when ready to merge
