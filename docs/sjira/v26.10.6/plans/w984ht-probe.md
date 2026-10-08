# W984ht — unclaimed-family probe: `lib/xaas/eds/`

Lane: W984ht · branch `feat/playwright-surface` · date 2026-10-07 · NO commit (coordinator owns transitions).

## Census and dispositions

`lib/xaas/eds/` = 3 modules, 468 LOC. All three have dedicated test files; probe
operated at branch level.

| module | file | test file | disposition |
|---|---|---|---|
| `Xaas.Eds.ExecutableResearchClaim` | `lib/xaas/eds/executable_research_claim.ex` (196 LOC) | `test/xaas/eds/executable_research_claim_test.exs` (covered) | **indirectly-covered** — dedicated suite never reaches: blank `artifact_ref` refusal, non-Falsifier struct refusal, claim-level implemented/executable/verified/reproducible/reproduced lifecycle, nil-execution_identity receipt projection, protocol in fingerprint, falsifier-order invariance, mixed run_falsifiers verdicts. Court covers all; **2 real defects found and fixed**. |
| `Xaas.Eds.EvidenceState` | `lib/xaas/eds/evidence_state.ex` (176 LOC) | `test/xaas/eds/evidence_state_test.exs` (covered) | **covered** — full classify spine, blocked-reason guard, non-collapse incl. off-spine miss. Residual branches courted: nil blocked_reason, survived-falsifier non-override, off-spine `:falsified` assert_non_collapse miss (pinned `refute result == :ok`). |
| `Xaas.Eds.Falsifier` | `lib/xaas/eds/falsifier.ex` (96 LOC) | `test/xaas/eds/falsifier_test.exs` (covered) | **indirectly-covered** — dedicated suite never exercises non-map `new/1` input or non-map `run/2` evidence. Court covers; **1 real defect found and fixed**. |

## Defects found and fixed (fix forward, no revert)

1. **ERC whitespace acceptance** (`executable_research_claim.ex` `require_binary/2`):
   `artifact_ref: "   "` was silently minted as a claim; `new/1` doc contract says
   "missing/blank" refused. Fixed to refuse whitespace-only values via `String.trim/1`
   (body-level check; guards cannot call String functions).
   Commit-by: court test "a blank artifact_ref must be refused".
2. **Falsifier.run/2 raised FunctionClauseError on non-map evidence**, violating its
   own @doc "Never raises to the caller" — the rescue clause never sees a guard-miss
   raise. Added a non-map clause returning `{:error, "falsifier evidence must be a map"}`.
3. Note: `EvidenceState.classify/1` can never return `:unknown`/`:unsupported` even
   though both are in `@states`/`states()`. Left as-is (documented vocabulary),
   disclosed in this receipt only.

# W984ht probe receipt (W984ht lane, 2026-10-07)

## What was done

1. Census: 3 modules, all with dedicated test files → branch-level probe.
2. Court file `test/xaas/eds/family_court_w984ht_test.exs` — 14 tests, real structs /
   real predicates / real SHA-256, zero mocks, mutation rationale in every test name.
3. 2 initial failures were real lib defects (whitespace acceptance, guard-miss raise);
   fixed forward in `lib/xaas/eds/` (2 files, both outside any other lane's touched set
   per `git status`).
4. Gates (all real output, exit 0):
   - `mix test test/xaas/eds/` under `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
     MIX_BUILD_ROOT=_build-laneW984ht` → `Result: 45 passed` (31 existing + 14 new), exit 0.
   - Mock gate: `scan_mock_usage(["test/xaas/eds"])` → `[]`.
5. Lane lease cleanup: `rm -rf _build-laneW984ht` → REMOVED (not denied).

## Standing

PARTIAL_ALIVE (lane-local): gates green on exact subject `feat/playwright-surface`
@ 009bd057 + lane diff. No commit (coordinator owns transitions). Zero other consumers
of `Xaas.Eds.*` outside `lib/xaas/eds/` + test/xaas/eds/ (grep-verified), so the two
lib fixes have no external blast radius.

## Falsifiers

- Family court file must stay green: `mix test test/xaas/eds/` exit 0.
- Mutation falsifier: reverting either lib fix must fail its court test
  (whitespace test pins refusal; non-map run/2 test pins the error tuple).
