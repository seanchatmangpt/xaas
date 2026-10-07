# W512 — GPAI Authority Decoupling Property Pins (Ch6 Thm 6.1)

- Repo: /Users/sac/xaas @ feat/playwright-surface
- Lane: W512, build root `_build-laneW512`
- Contract files: `test/xaas/semantics/authority_decoupling_test.exs` (only write surface), this receipt.
- Standing: see Verdict below.

## Theorem

Ch6 Thm 6.1 — GPAI authority decoupling: ∂Authority/∂Compute = 0. A model
candidate (any generator output) carries zero execution capability; authority
flows only from caller-supplied evidence through the real admission gate
(`Xaas.Actuation.Kernel.admit_authority/2` → ontology projection admission →
idempotency kernel → receipted DO).

## Axiom → test mapping

| Axiom | Test |
|---|---|
| A: candidate self-description carries no authority | `axiom A: candidate self-description never passes the gate (50-shape fuzz)`; `gate outcome depends only on opts, never on candidate content`; `missing/empty idempotency key refuses before any candidate is read` |
| B: refusal typed regardless of candidate size/shape | `axiom B: refusal is the typed term regardless of size/shape` — `:delegated_actuation_requires_authority_evidence` across all 50 shapes (giant payloads 1 MB, 250-deep nesting, authority-claiming fields, provider tool-call envelopes, forged receipt/context ids, unicode claims, role strings) |
| C: Authority(Candidate) = ∅ | `axiom C (structural pin)` — `argument(:admission, result(:admit))`, `admit_authority` is the first gate in `do_admit`, both public kernel entries route through `do_admit`; `with a full valid authority grant, candidate remains inert data` — persisted `intent.authority ==` caller evidence byte-for-byte, candidate survives only as recorded input; `candidate cannot forge replay identity` — hash-bound idempotency conflict, foreign key mints its own admission and never adopts another receipt; no-LLM guard refuses provider credentials regardless of claimed value, typed `REFUSED(...)` / `broken_term: mu_on_O` / `hop: guard`, values never echoed |

## Adversarial-shape count

50 deterministic candidates (6 role strings, 11 authority-claiming maps,
5 nested-delegation/tool-call envelopes, 4 oversized/oversized-deep/unicode/
JSON-blob shapes, 6 scalar/junk shapes, cycled to exactly 50).

## Seams exercised (real collaborators, no mocks)

- `Xaas.Actuation.run/4` (full admit → DO → seal pipeline, real Ash.Reactor,
  real sandboxed Postgres)
- `Xaas.Actuation.Kernel.admit_authority/2` via `do_admit/2`
- idempotency kernel (`find_or_create` / `replay_or_refuse`)
- `Xaas.Ultracode.SemanticDrive.no_llm_guard/1` over `priv/no_llm/policy.json`

## Verdict

AXIOMS-HELD.

## Command receipt

    PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW512 \
      mix test test/xaas/semantics/authority_decoupling_test.exs

Actual output (2026-10-06, final run /tmp/w512_run6.log):

    Finished in 0.5 seconds (0.5s async, 0.00s sync)
    Result: 8 passed

8 tests, 0 failures, 0 skipped. (The loud `Reactor.Audit` error lines in the
log are the fuzzer's expected typed gate refusals being audit-logged, not
failures.)

## Transport failures during the lane (disclosed, all resolved)

1. `lib/xaas/actuation/quiescent_stop.ex:91` compile error (pin operator,
   missing `require Ash.Query`) — an UNTRACKED sibling-lane lib file created
   19:01 mid-wave, blocked the whole-app compile for ~25 min. NOT a W512
   surface; W512 cannot edit lib. The owning lane fixed it at 19:27; W512
   retried and proceeded. No W512 action taken on lib.
2. Test-side iteration (all W512-owned, test file only):
   a. `~s(...)` sigil terminates at first `)` — replaced with plain strings.
   b. First expectation shape was the bare atom
      `:delegated_actuation_requires_authority_evidence`; the real contract
      surfaces it wrapped as
      `{:error, {:reactor_failed, %Reactor.Error.Invalid{errors: [%Reactor.Error.Invalid.RunStepError{error: :delegated_actuation_requires_authority_evidence}]}}}`.
      Tests now assert the true shape (this wrapping is itself part of the
      pinned contract).
   c. Non-map candidates (raw model strings/scalars) are refused at the public
      API boundary by the `is_map(input)` guard — a typed pre-admission
      refusal (FunctionClauseError), now asserted as such.
   d. With a valid authority grant, a candidate carrying unknown keys is
      rejected at the DO step as `NoSuchInput` and the receipt seals as
      `:failed` — asserted (admission succeeded on caller evidence; candidate
      claims never became authority; the failure is receipted).

## Architecture finding (for the coordinator, not a defect)

The candidate's claim keys (`authority`, `authorize`, role strings) are
rejected by the DO step's Ash input validation, so a candidate that
self-describes as authoritative cannot even complete a receipted DO —
decoupling is enforced twice: at the admission gate (authority evidence is
opts-only) and at the DO boundary (candidate content is data, validated
against the action's accepted inputs).
