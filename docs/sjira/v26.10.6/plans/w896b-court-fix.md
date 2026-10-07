# W896b — release_audit enoent court: court-shape fixes

Lane: W896b, xaas v26.10.6, canonical checkout `/Users/sac/xaas`
(branch `feat/playwright-surface`). Date: 2026-10-07.
Parent record: `docs/sjira/v26.10.6/plans/w896-enoent-court-owner.md` (W896,
2/4 — both court-shape defects, no lib defects). No commit (per dispatch);
only file written: `test/xaas/release_audit_enoent_court_test.exs`.

## Fix 1 — W845 asserts vs wrapped REFUSED shape

`capture_refusal_lines/1` returns full `REFUSED(release_audit, detail:
%{finding: "…"})` lines (`render_refusal/1` at
`lib/mix/tasks/xaas.release_audit.ex:81`). The W845 court previously used
`String.contains?` of the bare finding against those wrapped lines. Replaced
with explicit extraction of the bare finding strings from the wrapped shape
(`Regex.scan(~r/REFUSED\(release_audit, detail: %\{finding: "([^"]*)"\}\)/)`),
then set-membership `finding in findings`. Non-vacuous: an empty extraction
(`[]`) fails every membership assert, and the mutation rationale from W896's
record (typed-absent arms observed working) is preserved — the asserts still
require the five exact findings.

## Fix 2 — source-shape scan vs OS-19/W700 `@version` read

The scan at court-test line ~74 scopes to the `def run` body (module
attribute `@version File.read!("VERSION")` at
`lib/mix/tasks/xaas.release_audit.ex:14` is outside that scope) and its
pattern targets only `.tool-versions`/`Dockerfile`. The OS-19/W700 exemption
is now asserted in place with provenance: comment citing OS-19/W700 and
`w896-enoent-court-owner.md`, stating `@version` is a known-allowed
derive-from read, not an unguarded W872 scan site. Behavior unchanged;
documentation of the exception made explicit per dispatch option (b).

## Note on W896's observed 2/4

Before my edits, the unmodified court already ran 4/4 on the current tree
(first lane run, 2026-10-07): the wrapped lines literally contain the bare
findings (substring hit) and the scan pattern never matched `VERSION`. The
2/4 W896 observed is consistent with the tree state at its run time
(concurrent W900-batch lanes were changing scan coverage, e.g.
`.tool-versions`-scoped text-integrity arms). The two court-shape defects
W896 named were real robustness gaps either way and are now closed
explicitly (extraction + provenance-commented exemption), so the court no
longer depends on substring luck or an implicit scope accident.

## Verification (real run, pinned toolchain, lane build root)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW896b \
  mix test test/xaas/release_audit_enoent_court_test.exs
...
Finished in 0.3 seconds (0.00s async, 0.3s sync)
Result: 4 passed
```

Real tails observed in captured stderr: all five expected findings present in
wrapped form, e.g.:

```
REFUSED(release_audit, detail: %{finding: "tracked JSON file absent in worktree: absent.json"})
REFUSED(release_audit, detail: %{finding: "stale-claim scan: tracked file absent in worktree: absent.md"})
REFUSED(release_audit, detail: %{finding: "cannot read tracked text file absent.json: :enoent"})
```

Transport note (disclosed, pre-existing, other lanes): two earlier runs this
session failed to compile on in-flight edits by concurrent lanes
(`lib/xaas/library/checkout.ex` missing `require Ash.Query`, then
`lib/xaas/governance/audit_export_token.ex` increment/duplicate-route
transformer errors). Both resolved by those lanes before the final green run;
no xaas lib file was touched by this lane.

## Standing

- `test/xaas/release_audit_enoent_court_test.exs`: **ALIVE** — 4/4 executed on
  the exact subject (uncommitted worktree state, branch `feat/playwright-surface`),
  real `run/0` executions over a real git fixture; mutation rationale
  preserved.
- **Note for W896's ownership record (`w896-enoent-court-owner.md`): court now
  4/4**; its manifest proposal may flip standing PARTIAL_ALIVE → COMMIT with
  the assertion-shape condition satisfied by this lane.

## Replay

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW896b \
  mix test test/xaas/release_audit_enoent_court_test.exs   # expect 4 passed
```

Leftover for coordinator: `_build-laneW896b/` deletion was permission-denied
in this lane — delete at integration per the fanout cleanup law.
