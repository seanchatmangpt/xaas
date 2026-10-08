# W984dq5 — SpgGate Integration Work Order

Lane W984dq5, xaas v26.10.7 campaign. Branch `feat/playwright-surface`.
Spec/design lane: **no code changes, no mix runs, no commit**. This
document is the executable work order for the future integration lane.

## Subject

`Xaas.Actuation.SpgGate` (`lib/xaas/actuation/spg_gate.ex`) — fail-closed
SPG identity admission gate for consequential DO. Inputs = W984dj2 court
receipt (`docs/sjira/v26.10.6/plans/w984dj2-spg-gate.md`) + W650x
adjudication (`docs/sjira/v26.10.6/plans/w650x-spg-findings.md`), both
read from disk this session; all line numbers below re-verified against
the file on disk at HEAD (2026-10-07).

- Current standing: **PARTIAL_ALIVE as a capability, UNKNOWN as an
  integrated path** (zero callers in `lib/`; re-grepped this session —
  only the module and `test/xaas/actuation/spg_gate_test.exs` reference
  `SpgGate`).
- Court surface: 5-test court at
  `test/xaas/actuation/spg_gate_test.exs` (green ×2 fresh roots,
  witnessed by W984dj2 receipt runs 2–3).
- Open finding: F2 — `fingerprint_token/1` raises untyped `KeyError`
  on the string-keyed shape `admit/1` itself accepts
  (`lib/xaas/actuation/spg_gate.ex:41`), deferred to this work order by
  W650x.

## 1. Integration seam (the gate's first caller)

**Decision: `Xaas.Actuation.Kernel.do_admit/2` in
`lib/xaas/actuation.ex` (line ~330, the `with` chain), via the existing
`authority:` keyword channel of `Xaas.Actuation.run/4`.**

### Seam rationale (why here, not elsewhere)

Considered and rejected:

- **`CausalAdmission`-style Ash resource validation**
  (`lib/xaas/actuation/validations/causal_admission.ex`): rejected. A
  resource validation fires per changeset, i.e. only on the resource
  actions that opt in — the gate would apply to a subset of DO, not the
  whole `run/4` surface, and the SPG identity is about the *actuation
  admission* (identity of the graph node carrying the DO), not about
  the resource's own attribute validity. Wrong altitude.
- **The Reactor `:admit` step boundary** (`Xaas.Actuation.Reactor`):
  rejected as the *sole* seam. `prepare_external/4` bypasses the Reactor
  and calls `Kernel.admit_external/2` directly; gating only the Reactor
  step would leave the external three-commit protocol un-gated — a
  widening of un-gated consequential DO, the exact drift the module
  docstring forbids.
- **A bridge module** (`lib/xaas/bridges/`): no bridge exists whose
  semantics match; inventing one is unreceipted design.

`Kernel.do_admit/2` is the single funnel through which BOTH the
transactional path (`run/4` → Reactor `:admit` step) and the external
path (`prepare_external/4` → `Kernel.admit_external/2`) pass, so gating
there covers the whole consequential-DO surface with one caller. The
`authority:` channel is the lawful precedent: W780 already established
that `run/4`'s `authority:` opt carries admission evidence maps, and
`CausalAdmission` established the opt-in-declaration-inside-authority
pattern (`authority["causal"]`).

### Call contract

Inside `do_admit/2`'s `with` chain, insert a new step immediately after
`admit_authority/2` (identity gate before authority evidence is even
consulted? No — after, so an authority-refused call keeps its existing
refusal precedence):

```elixir
with :ok <- admit_authority(args.authorize?, args.authority),
     {:ok, projection} <- Registry.admit(args.resource),
     ...
```

becomes:

```elixir
with :ok <- admit_authority(args.authorize?, args.authority),
     :ok <- admit_spg(args.authority),
     {:ok, projection} <- Registry.admit(args.resource),
     ...
```

New private function in `Xaas.Actuation.Kernel`:

```elixir
# SPG identity gate (W984dq5 work order). Absent `:spg` key in the
# authority map = no-op (opt-in, same shape as CausalAdmission's
# `causal` declaration). Present = SpgGate.admit/1 must open; any
# gate refusal is fatal to the admission (fail-closed).
defp admit_spg(authority) when is_map(authority) do
  case Map.get(authority, :spg) do
    nil -> :ok
    identity ->
      case SpgGate.admit(identity) do
        {:ok, _projected} -> :ok
        {:error, reason} -> {:error, {:spg_gate_refused, reason}}
      end
  end
end
```

Plus a `{:error, {:spg_gate_refused, _}}` clause path — note the error
already propagates correctly through the existing pipeline:

- `do_admit/2` `with` failure → Reactor `:admit` step error →
  `normalize_transaction_result/1` → `{:error, reason}` (transactional).
- External path: `Ash.DataLayer.rollback(resources,
  {:external_admission_failed, reason})` (already the existing shape at
  `actuation.ex:75`).

Call-contract rules the implementing lane must preserve:

1. **Opt-in**: absent `:spg` key = gate not consulted, behavior
   byte-identical to today (no existing caller passes `:spg`, so zero
   regression surface — witnessed by the zero-caller grep).
2. **No authority grant**: `SpgGate.admit/1` opening does NOT authorize
   anything; the W780 `admit_authority/2` checks still run first and
   unchanged. The gate is identity admission only, exactly as the
   module docstring claims.
3. **Refusal precedence**: `admit_authority/2` before `admit_spg/1`, so
   an authority-refused call never observes the SPG gate.
4. **Key channel**: read `Map.get(authority, :spg)` (atom key). A
   string-keyed `"spg"` in the authority map is IGNORED (no gate) —
   this is deliberate fail-closed-by-absence: the implementing lane
   must NOT add string-key fallback, which would widen the surface.
   Document this in a comment at the call site.
5. **No bypass**: do not add an SPG gate call anywhere else
   (`execute_action/8`, bridges, resource validations). One caller,
   one seam.

## 2. F2 refinement — pre-integration requirement

**Required in the same diff as the seam (W650x falsifier: a caller
landing without it means the diff must be refused or amended).**

`fingerprint_token/1` (`lib/xaas/actuation/spg_gate.ex:38-47`) must
return a typed refusal instead of raising `KeyError` on non-atom-keyed
input. Exact shape:

```elixir
@spec fingerprint_token(map()) :: tuple() | {:error, :spg_fingerprint_atom_keyed}
def fingerprint_token(identity) when is_map(identity) do
  cond do
    is_binary(Map.get(identity, :graph_id)) and
      is_binary(Map.get(identity, :graph_version)) and
      is_binary(Map.get(identity, :node_id)) and
      is_binary(Map.get(identity, :edge_id)) ->
      {
        identity.graph_id,
        identity.graph_version,
        identity.node_id,
        identity.edge_id,
        Map.get(identity, :projection_family)
      }

    true ->
      {:error, :spg_fingerprint_atom_keyed}
  end
end
```

Contract:

- Refusal atom: **`{:error, :spg_fingerprint_atom_keyed}`** (W650x's
  named candidate; adopt as final).
- The existing 5-test court's test 5 asserts the KeyError seam behavior
  — test 5 must be **amended** in the same diff: string-keyed input now
  expects `{:error, :spg_fingerprint_atom_keyed}`, not a raise. Test 4
  (atom-keyed fingerprint shape/determinism) unchanged and must stay
  green.
- Lawfulness of the seam unchanged: the only lawfully fingerprintable
  input remains the atom-keyed map `admit/1` returns (W984dj2 F2
  finding text). The refinement converts crash-refusal to
  typed-refusal; it does NOT accept string-keyed fingerprints.
- Design alternative rejected (recorded per W650x): `Map.get`-with-
  default (`nil` components silently fingerprinting) — that would
  produce a valid-looking tuple from invalid input, i.e. fail-OPEN at
  the fingerprint layer. Guard head over `Map.get` with typed refusal
  is the only shape consistent with F3's exact-boundary property.

Post-refinement call sites inside the integration diff must handle the
new error tuple: today none exist in `lib/` (zero callers), and the
seam contract in §1 does not call `fingerprint_token/1` — the
integration diff may OPTIONALLY extend the seam to attach
`SpgGate.fingerprint_token(projected)` into the admission context, in
which case it must handle `{:error, :spg_fingerprint_atom_keyed}` as
`{:error, {:spg_gate_refused, :spg_fingerprint_atom_keyed}}`. If the
lane does not extend, `fingerprint_token/1` keeps zero internal
callers (acceptable; it is the caller-facing receipt-identity surface).

## 3. Falsifier — the integration court

**A new court file `test/xaas/actuation/spg_integration_test.exs` must
exist and pass**, exercising the seam through the real product path
(Chicago: real `Xaas.Actuation.run/4` over real Postgres sandbox, no
mocks — nothing to mock, the collaborators are all real).

Required cases (minimum, each kills a named drift):

1. **Opt-in no-op**: `run/4` with authority map WITHOUT `:spg` key
   succeeds as before (kills gate-mandatory mutants).
2. **Gate-open DO**: `run/4` with `authority: %{spg: %{graph_id: "g",
   graph_version: "1", node_id: "n", edge_id: "e", state: :admitted}}`
   — DO executes, receipt `:succeeded` (kills inverted-gate mutants).
3. **Gate-refused DO**: same but `state: "PENDING"` — `run/4` returns
   `{:error, {:spg_gate_refused, :spg_not_admitted}}`, NO intent/
   receipt rows persisted (kills fail-open + non-typed-refusal
   mutants; also verifies the refusal happens BEFORE `find_or_create`,
   i.e. in `do_admit/2`'s `with`, not inside the Reactor `:do` step).
4. **Incomplete identity**: missing `node_id` →
   `{:error, {:spg_gate_refused, :spg_identity_required}}` (kills
   required-field-relaxation mutants).
5. **String-keyed identity accepted by admit/1's normalize path**:
   `authority: %{spg: %{"graph_id" => "g", ...}}` — the gate opens
   (normalize/1 handles it) proving the string-key tolerance is the
   gate's own documented normalize contract, not the seam's (kills
   wrong-layer-tolerance mutants; contrast with rule 4 of §1: the
   `"spg"` KEY ITSELF stays atom-only).
6. **F2 witness**: `SpgGate.fingerprint_token/1` on string-keyed input
   returns `{:error, :spg_fingerprint_atom_keyed}` (amended test 5 of
   the unit court also covers this; this case witnesses it from the
   integration side).
7. **External path parity**: `prepare_external/4` with a
   gate-refusing `:spg` identity →
   `{:error, {:external_admission_failed, {:spg_gate_refused,
   :spg_not_admitted}}}` (kills seam-coverage mutants — proves the
   single-funnel claim; if this case cannot pass without extra wiring,
   the §1 seam decision was wrong and must be re-adjudicated, not
   patched ad hoc in the court).

Court standards: same discipline as W984dj2's court — mutants named
per case, refuting-run-then-correct protocol if any case fails on
first derivation, fresh-root ×2 confirmation
(`MIX_ENV=test`, asdf shims, unique `_build-lane<name>` roots deleted
at integration per lane-lease law).

## 4. Acceptance criteria (standing transition)

`Xaas.Actuation.SpgGate` moves **PARTIAL_ALIVE → ALIVE as an
integrated path** when ALL of:

- [ ] F2 refinement landed in
      `lib/xaas/actuation/spg_gate.ex`: `fingerprint_token/1` returns
      `{:error, :spg_fingerprint_atom_keyed}` on string-keyed input,
      never raises; unit court amended + green.
- [ ] Seam caller landed in `lib/xaas/actuation.ex`
      (`Kernel.do_admit/2`, `admit_spg/1` private step, contract §1);
      `grep -rn SpgGate lib/` shows `actuation.ex` as a caller.
- [ ] Integration court `test/xaas/actuation/spg_integration_test.exs`
      exists, all 7 cases green on a fresh root, ×2.
- [ ] Existing unit court `test/xaas/actuation/spg_gate_test.exs`
      green (amended test 5) on the same roots.
- [ ] `mix test test/xaas/actuation_test.exs` (the Reactor boundary
      falsifier per project CLAUDE.md) still green — opt-in no-op
      proven against the standing boundary court.
- [ ] Zero bypass callers: `grep -rn "SpgGate" lib/` hits exactly
      `spg_gate.ex` and `actuation.ex`.

Standing stays PARTIAL_ALIVE/UNKNOWN until every box is witnessed by a
receipt; a partially-checked diff is BLOCKED, not ALIVE.

## Receipt

- **Subject**: SpgGate integration work order, authored 2026-10-07,
  branch `feat/playwright-surface`, files read at working-tree state
  (actuation.ex, spg_gate.ex, refusal.ex, causal_admission.ex, both
  upstream receipts). No SHA pinned by this lane (spec lane; the
  implementing lane pins base SHA per GitHub-task-normalize order).
- **O/O***: W984dj2 court + W650x adjudication (both on disk,
  read this session); current sources re-read line-level this session.
- **Transport failures**: none. No mix commands run (lane law).
- **μ/diff**: this document only (one file);
  generated-vs-handwritten: handwritten, unreduced residue = none —
  the Elixir snippets in §1/§2 are contract sketches for the
  implementing lane, not landed code.
- **Commands/exits**: `grep -rln SpgGate lib/` (2 files: module +
  nothing in lib/ outside it; zero callers — re-witnessed);
  `ls` of actuation dirs. Exit 0.
- **Replay**: re-read the two upstream receipts + the four source
  files named above at the implementing lane's base SHA; if
  `Kernel.do_admit/2`'s `with` chain has drifted from the shape
  assumed in §1 (admit_authority first, Registry.admit second), the
  seam insertion point must be re-derived, not assumed.
- **Standing**: `Xaas.Actuation.SpgGate` remains PARTIAL_ALIVE
  (capability) / UNKNOWN (integrated path) — unchanged by this lane;
  this work order is the admission path out of UNKNOWN.
- **Falsifiers**: §3 court; W650x's deferral falsifier (caller
  without F2 in same diff → refuse/amend).
- **Standing verdicts**: seam decision FINAL for this campaign unless
  §3 case 7 falsifies it; F2 refusal atom FINAL
  (`:spg_fingerprint_atom_keyed`).
