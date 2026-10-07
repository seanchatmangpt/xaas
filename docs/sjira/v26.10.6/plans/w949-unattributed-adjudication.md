# W949 — Unattributed-file adjudication (W946d residue closure)

- **Date**: 2026-10-07
- **Lane**: W949 (read-only adjudication; no commit, no build root)
- **Subject**: /Users/sac/xaas @ `feat/playwright-surface`, HEAD `fab56ae1`
- **Task source**: W946d runbook residual finding — 3 files with no owning receipt
  (marked UNKNOWN owner). Method: `git diff HEAD -- <path>` read hunk-by-hunk,
  matched against landed receipts' exact claimed content.
- **Standing**: ALIVE (adjudication only; every assignment below is backed by
  verbatim hunk-to-receipt content match, not name similarity)

## Per-file adjudication

### 1. `lib/xaas/semantics/computation.ex` — TWO owners, both confirmed

The diff contains two disjoint change classes:

**(a) Four @doc/doctest blocks → W853** (`w853-computation-doctests.md`, HIGH)

The four added `@doc` blocks carry exactly the four expected-hash strings W853's
receipt transcribed from its real `mix run -e` probes:

| Hunk | Function | Expected hash in diff | W853 receipt value |
|---|---|---|---|
| :66 | `ComputationArtifact.hash/1` | `14c69125e2dd6a21…` | same (verbatim) |
| :91 | `ComputationHash.hash/1` | `2bd10397da30531a…` | same (verbatim) |
| :186 | `ComputationClaim.hash/1` | `c252f6a5ddc64f23…` compared to the W853 receipt's `c252f6a5…` | same (verbatim) |
| :289 | `PlanningAdvice.hash/1` | `488187d431e24e42…` | same (verbatim) |

W853's declared scope was "only `lib/xaas/semantics/computation.ex` (@doc blocks
only)" — matches exactly. W907 is **not** an owner: its scope is explicitly
`counterfactual.ex` only; its post-restore green run merely co-ran
`computation_doctest_test.exs` (run evidence, not authorship).

**(b) `validate_evidence_class/1` refactor → W782** (`w782-claim-label-fix.md`, HIGH)

The hunk replacing `evidence_class when evidence_class in @evidence_classes <-`
with `{:ok, evidence_class} <- validate_evidence_class(...)` plus the two
`defp` clauses and the new refusal atom `:computation_claim_invalid_evidence_class`
is verbatim W782's receipted fix (W763 finding G2 — evidence-class failures
mislabeled as standing refusals). W782's declared scope: "computation.ex …
this receipt".

**Proposed commit group**: split-stage the file (`git add -p` style): the
validate_evidence_class hunk + its boundary-court companion
`test/xaas/sa2a_computation_boundary_test.exs` (already committed in CG-07a,
`181ba1f6` — verify there) → **CG-07-family residual: "fix(semantics):
ComputationClaim evidence-class refusal relabel (W782)"**; the four doctest
@doc blocks → **"docs(semantics): computation hash doctests (W853)"** — or, if
partial staging is rejected for risk, one residual semantics commit
"W782+W853" is defensible since both receipts are landed and mutation-verified.
Confidence: HIGH (both).

### 2. `docs/claude/diataxis/reference/http-api-surface.md` — W885b, confirmed

Diff content is the W885b note block, near-verbatim: read-only routes cite
(`route_castle_run.ex:42-46`), empty-attributes Ash-3 `public?` explanation,
"lawful fix is `public?(true)` plus `mix ash.codegen` — not a hand edit
(W858 … finding F1)", private unrouted `:execute` (`:57-66`). W885b's receipt
claims exactly this file and exactly this content; only the attribute-block
line-cite differs (`72-76` in the doc vs `69-77` in the receipt — cosmetic,
both point at the same attributes block).

**Proposed commit group**: diataxis reference residual — fold into the next
CG-13b-family docs commit: **"docs(reference): RouteCastleRun wire-projection
note (W885b)"**. Confidence: **HIGH**.

### 3. `e2e/internal-api.spec.cjs` — content matches W836/W860 court; NO author receipt → NEEDS-REVIEW

The diff edits W752's original health spec to accept the W836-pinned contract:
aggregate stays 200/`"ok"` while `ultracode_tick` is `skipped(:warming_up)`
inside the boot+7min grace, with a typed skip-reason assertion. The content is
fully consistent with the landed health-court receipts (W836 court content,
W860's timeout repair "co-run green" against W752's spec).

However, **no receipt claims authorship of this edit**: W836's files-written
list is controller + court test + receipt; W860's is controller + court test +
receipt ("Files written: controller, court test, this receipt only"); W752
validated but did not author it; W940 explicitly left it unstaged/unowned;
W946d flagged it UNKNOWN. Also note the spec edit was never witnessed passing
in any receipt I found (W752's runs predate it; W860 co-ran the *router* test,
not the playwright spec).

**Proposed commit group**: health-court family (CG-09-family residual):
**"test(e2e): internal-api health spec accepts warming_up skip contract (W836)"**
— but standing is **NEEDS-REVIEW**: require a real playwright run of
`e2e/internal-api.spec.cjs` against a test-env server (per W752's documented
manual-boot + `reuseExistingServer` path) before commit, OR an owning lane
confirms authorship. Confidence: **needs-lane-confirm**.

## Standing summary

| File | Owner(s) | Confidence | Commit group |
|---|---|---|---|
| `lib/xaas/semantics/computation.ex` | W853 (doctests) + W782 (evidence-class) | HIGH | CG-07-family residual, split or combined |
| `docs/claude/diataxis/reference/http-api-surface.md` | W885b | HIGH | CG-13b-family residual |
| `e2e/internal-api.spec.cjs` | none (content = W836 contract) | needs-lane-confirm | CG-09-family residual, gate on real e2e run |

## Verification ladder

- `git diff HEAD` read per file (all hunks inspected, none skipped).
- Receipts read in full: W853, W907, W885b, W836, W782, W940, W944, W867, W881, W946d.
- No receipt contradicts any assignment above; W907 explicitly excluded by scope.

## Falsifier

Any landed receipt claiming one of these hunks with a different owner, or a
`git log -p` on the eventual commit showing content not present in the diffs
adjudicated here, falsifies this adjudication.
