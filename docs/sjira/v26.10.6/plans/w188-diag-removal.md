# W188 — DIAG_CLAIM instrumentation removal (command_bus.ex)

Lane: W188, v26.10.6 convergence. Repo: /Users/sac/ash_a2a.

## Observation (O → O*)

Dispatch reported stray debug instrumentation in
`lib/ash_a2a/command_bus.ex`: `DIAG_CLAIM_RESCUE`/`DIAG_CLAIM_CATCH`
markers as an untracked working-tree edit.

Verified on the canonical checkout at HEAD `07180bd3`:

- `git diff lib/ash_a2a/command_bus.ex` → empty (no working-tree edit exists).
- `git diff HEAD lib/ash_a2a/command_bus.ex` → empty.
- `git grep -n "DIAG_CLAIM" HEAD -- lib/` → zero matches.
- `grep -rn "DIAG_CLAIM" lib/` → zero matches (working tree).

Classification: **already removed / never present on this subject** —
not "reverted by W188". Nothing to revert; `git checkout --` was not
needed and was not run against a dirty file.

## Action

No revert required. The working tree for `lib/ash_a2a/` contains exactly
one modification, the sanctioned W130 fix:

- `lib/ash_a2a/authzen/client.ex` — `System.system_time(:millisecond)` →
  `System.monotonic_time(:millisecond)` for DecisionPool cache TTL
  (3 lines + explanatory comment).

## Verification (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/ash_a2a/command_bus_test.exs
Result: 9 passed
```

Post-state:

```
$ git diff lib/ash_a2a/ | grep -E "^(diff|index)"
diff --git a/lib/ash_a2a/authzen/client.ex b/lib/ash_a2a/authzen/client.ex
index 53f5b395..56975f64 100644
$ git status --short lib/ash_a2a/
 M lib/ash_a2a/authzen/client.ex
```

## Standing

- DIAG removal: OBSERVED-ALREADY-CLEAN (no diff to revert; no edits made by W188).
- command_bus tests: ALIVE — 9/9 passed on exact working-tree subject.
- Remaining `lib/ash_a2a/` diff = W130 monotonic-time fix only, as expected.

Falsifier for the original claim ("stray DIAG edit present"): `git diff
lib/ash_a2a/command_bus.ex` returns empty on this checkout — claim does
not hold at subject 07180bd3.
