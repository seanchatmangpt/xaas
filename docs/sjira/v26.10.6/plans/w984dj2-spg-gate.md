# W984dj2 — SpgGate First Depth Court

Lane W984dj2, xaas v26.10.6 campaign. Branch `feat/playwright-surface`,
HEAD at court time `56325fa5`. No commit (per lane law — coordinator
integrates).

## Subject

`Xaas.Actuation.SpgGate` (`lib/xaas/actuation/spg_gate.ex`) — fail-closed
Semantic Procedural Graph identity admission gate for consequential DO.
Backlog note from W984cw3: 3 public functions, 0 direct test references.

## Module surface analysis

- `admit/1` — the only admission surface. Two heads: map head (validate +
  normalize + project) and catch-all `admit(_) -> {:error, :spg_identity_required}`.
  Gate opens only when (a) all four required identity fields
  (`graph_id`, `graph_version`, `node_id`, `edge_id`) are non-empty
  binaries, and (b) `state` is exactly `:admitted` or `"ADMITTED"`.
  Returns `{:ok, projected}` with exactly
  `@required ++ [:projection_family, :state]`.
- `fingerprint_token/1` — atom-key tuple access, no default. Raises
  `KeyError` on string-keyed input. No spec-guard, no fallback head.
- `normalize/1` (private) — converts the six known string keys to atoms;
  unknown keys pass through unchanged.
- **Callers: zero.** Confirmed by grep over `lib/` and `test/` before this
  court: no module in the tree calls SpgGate. It is an unadmitted gate —
  the module doc's claim ("the existing XaaS Actuation/BRCE authority path
  remains exclusive") holds trivially because nothing routes through it.
- Dead-code note: `Map.get(normalized, :state) not in [:admitted, "ADMITTED", "ADMITTED"]`
  — the duplicate `"ADMITTED"` in the accept list is a dead literal, a
  residual of an earlier `:ADMITTED`-atom spelling drift.

## Standing of findings

Both findings below are **observed, not inferred**: the first run of the
court refuted my initial hypotheses (lowercase `"admitted"` accepted;
string-keyed fingerprints supported). 3/5 tests failed on run 1; the tests
were re-derived from the refuting output and re-run green. The gate's
real posture is stricter than its type spec suggests.

### F1 — state vocabulary is exact-match, case-sensitive, atom-or-upper-string

`admit/1` accepts only `:admitted` or `"ADMITTED"`. Lowercase `"admitted"`
→ `{:error, :spg_not_admitted}`. Fail-closed, but a caller passing the
atom-to-string-lowercase convention would be refused. Standing:
ALIVE (witnessed by test 3, runs 1+2).

### F2 — fingerprint seam is atom-key-only, crashes otherwise

`fingerprint_token/1` on a string-keyed identity (the raw ontology/JSON
shape `admit/1` itself accepts) raises `KeyError` at
`lib/xaas/actuation/spg_gate.ex:41`. Fail-closed by crash, not by typed
refusal. The only fingerprintable input is the atom-keyed map `admit/1`
returns — so the lawfulness of the seam is: fingerprint only what the
gate admitted. Standing: ALIVE (witnessed by test 5, run 1 KeyError).

### F3 — typed refusal shape at the exact boundary

Only two refusals exist, both typed atoms: `:spg_identity_required`
(missing/empty required field, or non-map input) and `:spg_not_admitted`
(any non-admitted state). Per-field fail-closed (each of the four
required fields independently refuses on missing and on empty-string).
Standing: ALIVE (witnessed by test 2).

## Test surface

`test/xaas/actuation/spg_gate_test.exs` — 5 tests, real invariants, no
mocks (nothing to mock: pure functions over real maps):

1. Gate-open + exact projection shape (kills take-list mutants).
2. Per-field fail-closed over all 4 required fields × {missing, empty} +
   non-map inputs (kills non_empty? relaxation and head-removal mutants).
3. Exact state vocabulary — refuse `PENDING` and lowercase `admitted`,
   admit `:admitted` and `"ADMITTED"` (kills state-check-drop and
   case-normalizing mutants).
4. Fingerprint determinism + full tuple shape + projection_family
   sensitivity (kills component-drop and reorder mutants).
5. Seam: KeyError on string-keyed fingerprint; `admit/1` projection
   fingerprints identically to its atom-keyed source (kills
   check/projection drift mutants).

## Verification receipt

Toolchain: asdf shims, `MIX_ENV=test`.

- Run 1 (fresh root `_build-laneW984dj2`, cold build ~18 min):
  `mix test test/xaas/actuation/spg_gate_test.exs` — **2/5 passed,
  3 failed** (refuting run, findings F1/F2 derived from it; exit 0 per
  ExUnit convention captured by shell).
- Run 2 (warm root `_build-laneW984dj2`, post-correction):
  **Result: 5 passed.**
- Run 3 (fresh root `_build-laneW984dj2b`, ×2 fresh-root directive):
  **Result: 5 passed.**

## Disposition

`Xaas.Actuation.SpgGate` is not thin and not a placeholder — it is a
real, working, fail-closed admission kernel with exact typed refusals.
Its standing is **PARTIAL_ALIVE as a capability, UNKNOWN as an integrated
path**: fully exercised at unit/property level by this court, but with
zero callers, so no production seam currently carries its DO. First depth
court satisfied; next depth would be an integration court once a caller
seam exists.

## Lane hygiene

Build roots `_build-laneW984dj2` (left for coordinator per lane law —
warm, reusable) and `_build-laneW984dj2b` (fresh-root confirmation, left
for coordinator cleanup discretion). No files outside `test/xaas/
actuation/` + this receipt were touched.

## Follow-up adjudication (appended by lane W650x, 2026-10-07)

C23 pruner discipline applied to findings F1/F2. No code changes; this
append and `w650x-spg-findings.md` are the only artifacts.

### Caller question (re-grounded)

Re-grep 2026-10-07 over `lib/` and `test/` (`grep -rn SpgGate`): the
module and its test file remain the only references — **zero call sites
in `lib/`**, unchanged from the court above. Standing stays as written:
**PARTIAL_ALIVE as a capability, UNKNOWN as an integrated path**. This
matches the forward-capability class (like the wasm host before W638):
the gate is an awaiting-integration kernel, not dead code for the
pruner — the integration court named above is its lawful next depth.

### F1 — DESIGN-ACCEPTED

Case-sensitivity of the state vocabulary is the admission contract, not
a defect. The refusal is already typed (`{:error, :spg_not_admitted}` —
finding F3's exact boundary), so a non-canonical state spelling is
refused with a typed atom, not a crash; fail-closed and non-lossy for
the caller. `admit/1`'s catch-all plus the exact-vocabulary check define
a strict identity boundary; normalizing (e.g. accepting lowercase or
upcasing) would *widen* the admission surface of a DO gate, which is the
one direction this module must not drift. If any future caller needs to
present lowercase/raw state vocabulary, the normalization is that
caller's decision at its own boundary, with its own disclosure.

### F2 — typed-refusal refinement RECOMMENDED (deferred to integration lane)

The `fingerprint_token/1` KeyError on string-keyed input is fail-closed
by crash — the crash does refuse the input, but untyped, and it
collapses a caller bug into an exception rather than a
`{:error, atom()}` like every other refusal in the module. A typed
refusal (e.g. `{:error, :spg_fingerprint_atom_keyed}` or a guard head
mirroring `admit/1`'s catch-all) is the refinement. Per C23 discipline
it is **not** this lane's or W650x's work: with zero callers there is no
production seam to protect, and the refinement belongs in the
integration lane's work order, where a real caller shape fixes the
correct refusal contract. Recommendation recorded for that lane; no
code change now.
