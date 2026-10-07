# W984da — Security family depth probe (lane receipt)

Lane: W984da, v26.10.6 campaign, repo `/Users/sac/xaas`, branch
`feat/playwright-surface` (HEAD `cab79623` at lane start). No commit made
per lane contract; test file + this receipt are the only writes.

## Family census — lib/xaas/security/

W984cj-map method (module enumeration + existing-test grep):

| module | lines | state-bearing surface | prior coverage |
|---|---|---|---|
| `lib/xaas/security.ex` (domain) | 115 | ingest/1 (map + path clauses), atomize/1 passthrough, parse_dt/1, posture_summary/0 fold | 4 happy-path tests (`test/xaas/security/security_test.exs`) |
| `lib/xaas/security/finding.ex` | 77 | ETS Ash resource, severity/source/disposition one_of enums, deny-by-default policy floor w/ read bypass | ingest happy path only |
| `lib/xaas/security/posture.ex` | 49 | ETS Ash resource, per-severity counts, green flag, register action | counts happy path only |

No scan/vuln surfaces exist beyond this trio; Finding/Posture were already
deepened in the W984aa era only as ingest fixtures. The genuinely
uncovered state-bearing slices: path ingest, policy floor on writes,
unknown-enum passthrough, vacuous-empty green semantics, cross-scan fold.

## Court — `test/xaas/security/finding_lifecycle_depth_test.exs`

5 tests, Chicago style (real Ash actions, real ETS data layer, zero
mocks), each with mutation rationale:

1. **path ingest** — kills deletion of the `File.read! -> Jason.decode!
   -> ingest/1` binary clause (would surface as FunctionClauseError).
2. **policy floor** — `Ash.create(..., authorize?: true)` on Finding
   returns `{:error, %Ash.Error.Forbidden{}}`; kills deletion of the
   `policy always() forbid_if(always())` floor in finding.ex.
3. **unknown disposition** — `"waved_through"` raises typed
   `Ash.Error.Invalid` via the one_of constraint (atomize/1 passes the
   binary through instead of creating an atom); kills mutation of the
   ArgumentError rescue arm; asserts no Finding row leaks.
4. **vacuous empty scan** — zero findings -> zero counts, green true
   (`Enum.all?/2` over [] by design); kills all?->any? flip.
5. **cross-scan fold** — empty estate green=false (`postures != []`
   guard), two-scan count sums, one red scan keeps the estate red;
   kills all?->any? in the green fold and guard-drop mutations.

## Execution

- Run 1 (fresh root `_build-laneW984da`): 4/5, test 3 failed on
  refusal shape (ingest uses `Ash.create!` -> raise, not error tuple);
  fixed test to `assert_raise Ash.Error.Invalid`.
- Run 1' (same root, warm): **5 passed**.
- Run 2 (second fresh root `_build-laneW984da-fresh2`, full rebuild):
  **5 passed** (exit 0).
- Regression: pre-existing `test/xaas/security/security_test.exs` —
  4 passed (unaffected).

Transport note: shared `lib/xaas/semantics/graphlaw_wasm.ex` was
mid-edit by another lane for ~15 min (defp-after-end, then delimiter
mismatch); per the compile-freeze SLA I waited rather than touching it;
the owning lane repaired it and my court compiled unchanged.

## Standing

Court: **ALIVE** (5/5 on two independent fresh build roots). Disposition: family NOT fully covered —
`parse_dt/1` malformed-ISO8601 crash path (`{:ok, dt, 0}` match, raises
MatchError on offset input) remains a known thin slice, left for a
follow-up lane. Build roots `_build-laneW984da` and
`_build-laneW984da-fresh2` left for coordinator cleanup per lane law.
