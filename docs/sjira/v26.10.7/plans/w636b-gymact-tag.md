# W636b — gymact `__version__` drift sync + v26.10.7 tag

Lane W636b, v26.10.7 fleet seal. Closes W636's drift flag.

## Subject

- Repo: `~/gymact` (canonical checkout), branch `v26926/gymact-land-aloop-execution-kernel`
- Base HEAD: `dcda945a` (chore(release): bump version to 26.10.7 — the W618 authority)
- Commit: `8472ffd2115543599654f8c6ab6996b48b0e508e` — fix(release): W636b sync `__version__` to 26.10.7 (drift forward per w618/w636)
- Tag: `v26.10.7`, annotated, object `62835e7c12a42e7400a84eb928e02d63f034d65c` (type: tag)

## Drift (O)

`src/gymact/__init__.py` declared `__version__ = "26.10.6"` vs pyproject
`version = "26.10.7"` (release authority, W618). Working tree already carried an
uncommitted 26.9.28→26.10.6 edit; fixed forward past both to 26.10.7.

## μ / diff

1-line change, explicit pathspec commit (`git add -- src/gymact/__init__.py`):

```
-__version__ = "26.10.6"
+__version__ = "26.10.7"
```

No other files touched. Never force; pushes were fast-forward / new-ref.

## Commands / exits

- Edit via in-place replace (asserted exactly one occurrence) — OK
- `git commit -F /tmp/w636b-commit-msg.txt` → `8472ffd2`, 1 file changed (+1/−1)
- `git push origin v26926/gymact-land-aloop-execution-kernel` → `dcda945a..8472ffd2` (ff)
- `git tag -a v26.10.7 -m "gymact v26.10.7 — fleet seal release (W618 version bump; W636b __version__ drift sync)"` → OK
- `git push origin v26.10.7` → `[new tag]`

## Verification tails

- `git ls-remote origin`:
  - `refs/tags/v26.10.7` → `62835e7c…` (annotated tag object)
  - `refs/tags/v26.10.7^{}` → `8472ffd2115543599654f8c6ab6996b48b0e508e` — peels to local HEAD ✓
  - `refs/heads/v26926/gymact-land-aloop-execution-kernel` → `8472ffd2…` ✓
- `git cat-file -t v26.10.7` → `tag` (annotated)
- `git status --short src/gymact/__init__.py` → clean (exit 0)
- Import check: optional; attempted, blocked by missing `rfc8785` in bare
  python3 env (dependency absence, not the version line). Not a gate.

## Standing

ALIVE — exact subject observed: remote tag peels to the committed local HEAD;
version authority (pyproject) and runtime constant agree at 26.10.7.

## Falsifier

A future `git ls-remote origin refs/tags/v26.10.7^{}` not equal to the branch
head, or `__version__` in `src/gymact/__init__.py` diverging from pyproject
`version`, reopens this drift.
