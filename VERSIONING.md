# Versioning

This project uses **semantic versioning** (`vMAJOR.MINOR.PATCH`, e.g.
`v0.1.0`) so you can always roll back to a known-good state and the
version number itself says something about the size of the change.

Earlier releases (`v1`–`v8`) used flat whole-number milestone tags instead
— good practice at the time, but not semantic and not worth preserving
the scheme for. `v0.1.0` is the first release under the new scheme; it
isn't a continuation of the `v8` numbering, and the whole-number tags
before it remain in git history as-is (not renamed or removed).

## What each number means

- **MAJOR** — reserved for `1.0.0` (first release considered a complete,
  shippable game) and later breaking reworks. Stays `0` until then.
- **MINOR** — new player-facing content or systems (a new spell, enemy
  tier, mechanic). Roughly what the old whole-number tags used to mean.
- **PATCH** — fixes, balance tweaks, and polish that don't add new
  content.

## What counts as a version

- A version is a **stable milestone**, not every commit.
- Day-to-day work happens on feature branches and merges to `main`.
- When a milestone is ready, cut a new version.

## Files

| File | Role |
|------|------|
| `VERSION` | Current released version number (single line, e.g. `0.1.0`) |
| `CHANGELOG.md` | Human-readable history of each release |
| Git tag `vMAJOR.MINOR.PATCH` | Immutable pointer to the release commit (source of truth) |

The tag is authoritative. `VERSION` and `CHANGELOG.md` mirror it for humans and in-game display.

## Cutting a new version

1. Finish and test the milestone on a branch.
2. Update `VERSION` (e.g. `0.1.0` → `0.2.0` for new content, `0.1.1` for a fix-only release).
3. Add a dated section to `CHANGELOG.md` describing what changed.
4. Commit with message: `Release vX.Y.Z: <short summary>`.
5. Create an annotated tag:
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z: <short summary>"
   ```
6. Merge to `main` if the release commit is not already there.
7. Push when ready:
   ```bash
   git push origin main
   git push origin vX.Y.Z
   ```

## Rollback options

### Inspect an old version (read-only)

```bash
git checkout v1
```

You will be in detached HEAD state. Good for running or comparing old code.

### Branch from an old version

```bash
git checkout -b hotfix-from-v1 v1
```

Use this to patch an old release without disturbing `main`.

### Return to latest main

```bash
git checkout main
```

### Revert changes on main (without rewriting history)

If bad commits landed on `main` but were never tagged as a release, revert them:

```bash
git revert <commit-hash>
```

Prefer this over `git reset --hard` on shared branches.

### Reset main to a tag (destructive — use with care)

Only on local or private branches, or when you explicitly intend to rewrite history:

```bash
git checkout main
git reset --hard v1
git push --force-with-lease origin main
```

Avoid force-pushing to shared `main` unless everyone agrees.

## Listing versions

```bash
git tag -l "v*"
git log --oneline --decorate --tags
```

## In-game version display

The main scene reads `res://VERSION` at runtime and shows it in the UI label.
