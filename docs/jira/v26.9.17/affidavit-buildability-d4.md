# Affidavit Buildability D4 — committed tip must compile without uncommitted drift

## Summary

Disagreement D4, both sides true: the boundary court passed (352 tests) with
the operator's uncommitted `[patch.crates-io] wasm4pm-compat → local path`
drift in the working tree, but the *committed* tip `3106f64` does NOT compile
from a clean checkout (registry `wasm4pm-compat 26.6.13` fails, ~550 errors).
The issuance agent had to mirror the patch into its worktree (uncommitted,
provenance-commented) to build `affi` at all. A branch that only builds with
uncommitted local state is not landable.

## Status

Queued / Not Started (agent work; resolve before
`op-branch-landing-decisions.md` lands this branch).

## Scope

1. Reproduce: clean worktree from `3106f64` → `cargo build` → capture the
   registry failure (exit code + first errors).
2. Fix by precedence:
   - **Preferred**: make the committed code compatible with the registry
     crate version (upstream the API deltas the patch papers over), OR
   - Commit the `[patch.crates-io]` block if the local-path dependency is a
     deliberate monorepo coupling (document WHY in the commit message; note
     the CI implication — CI needs the sibling checkout materialized).
3. Court from a CLEAN checkout of the new tip: fmt, clippy (223 prior
   convictions were fixed on this branch — keep them fixed), full test suite
   (352+), e2e + cli_dispatch.
4. Receipt: clean-checkout build proof (exit codes), diff summary, court run.

## Key Invariant(s)

- `git clone && cargo test` must pass from the landed tip alone (or from the
  documented submodule/sibling contract, explicitly, in-repo).
- No drift-dependent greens: courts run on committed state only.

## Relationship to Existing Work

- `boundary-affidavit.md` (court-under-drift) vs `affidavit-issuance.md`
  (committed-tip failure) — D4 in `RELEASE-STATE-v26.9.17.md`.
- Unblocks landing `fix/affidavit-v26.9.17-boundary` and the issuance
  worktree branch.

## Falsifiers / What Would Defeat This

- A fix that only works with BOTH the patch and new registry pins (drift
  moved, not removed).
- Issued wave affidavit becomes unverifiable from the new tip (the artifact
  must still verify — rerun `affi receipt verify` after).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | queued | affidavit fix/affidavit-v26.9.17-boundary @ 3106f64 | committed tip: build FAILS (~550 errors); with drift: 352/0 | clean-checkout repro → fix → clean court |
