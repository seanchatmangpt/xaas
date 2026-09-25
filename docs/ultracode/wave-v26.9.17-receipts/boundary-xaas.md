# Boundary receipt — qualify-boundary(xaas, cap-system-authority) — agent 6/10

Date: 2026-09-17. FOND oneof: **qualified**. Standing: **ALIVE**.

## Pinned subject
- Repo: /Users/sac/xaas — head `fd686479e0c8c343e4f59beba3526e31f7dcf407` (matches pinned fd68647), branch `feat/execution-actuation-fabric`.
- Head commit: `fix(execution-fabric): normalize standing casing at the transport — honest ALIVE was silently downgraded`.
- Re-pinned via `git rev-parse HEAD` at session start; no movement of HEAD during the run (only sibling commits touch priv/templates/zcode_plugin/*, which I did not read-modify).

## Dirty-file inventory (15 entries, classified drift)
Sibling territory (their commits only; untouched by me):
- `priv/templates/zcode_plugin/commands/xaas.md.eex` (M)
- `priv/templates/zcode_plugin/hooks/post_tool_failure.mjs.eex` (M)
- `priv/templates/zcode_plugin/hooks/post_tool_use.mjs.eex` (M)
- `priv/templates/zcode_plugin/hooks/user_prompt_submit.mjs.eex` (M)
- `priv/templates/zcode_plugin/hooks/xaas-lease.mjs.eex` (M)
- `priv/templates/zcode_plugin/hooks/xaas_common.mjs.eex` (M)
- `generated/` (untracked, ignored per constraints)

Boundary-adjacent drift (ON my boundary, uncommitted, NOT sibling territory — reported, not committed; tests ran green WITH it in the tree):
- `lib/xaas_web/controllers/execution_fabric_controller.ex` (+16): `reason_atom/1` hardened — `String.to_atom/1` on attacker-controlled MCP `refuse` reason input replaced by `String.to_existing_atom/1` with `:unknown` fallback. Closes an atom-table-exhaustion DoS (BEAM atoms are never GC'd).
- `test/xaas_web/execution_fabric_controller_test.exs` (+42): matching negative test — a novel attacker reason string never crashes, never interns a new atom (re-checked with `list_to_existing_atom` raising before AND after), and the unresolvable reason still lands as inspectable evidence (`refusal_reason == "unknown"`) in the sealed receipt; epoch lands `:failed`.

Other drift (docs/ledger, not code):
- `HANDWRITTEN.md` (M), `.agents/rules/`, `docs/adr/`, `docs/architecture.md`, `docs/context/`, `docs/target-architecture.md` (all untracked).

## Commands + exact exits (every mix under /tmp/uzc/xaas-mix.lock)
1. `mix compile --force --warnings-as-errors` → **exit 0**. xaas app: 402 files compiled, 0 errors, 0 project warnings (all warnings in log are third-party deps, non-gating).
2. `mix test --only ultracode` → **8 tests, 0 failures, 680 excluded**, ~3.8s. Covers the epoch-loop quartet: `run_start_test` (Run.:pending→:running admission + unattended create→start→4 ticks→completed, 2 epochs, 4 receipts, zero manual Epoch construction), `next_epoch_test` (2 full epochs across 4 Reactor ticks), `epoch_reactor_test`, `missed_epoch_receipt_test` (expected→missed seals receipts; missed-epoch warnings observed firing live in the log).
3. `mix test` (full suite) → **exit 0. 648 tests, 0 failures, 40 excluded**, 13.4s. (Prior baselines in docs/ultracode/PROGRESS.md: 488/0 and 490/0 at earlier SHAs; branch has moved past them. Transient Req.TransportError retries inside tests are handled and green.)
4. Tripwire probe (one locked run): `mix test test/xaas/ultracode/lease_test.exs test/xaas_web/execution_fabric_controller_test.exs test/xaas/actuation_test.exs` → **exit 0, 30 tests, 0 failures** (13 + 13 + 4).

## Tripwire citations (what each guards)
`test/xaas/ultracode/lease_test.exs` — 13 tests, the admission court:
- `admit_tool/2`: allows construction tools under a live lease (Edit allowed); **refuses consequence tools under the no-ceiling fence** — `{:error, {:refused_no_authority, "git_push"}}` and `{:error, {:refused_no_authority, "Bash"}}` (the Bash/git_push/publish refusal the mission names); **unknown tool classes fenced** (`TimeMachine` → `{:error, {:unknown_tool_class, ...}}` — UNKNOWN ≠ allowed); no lease → no admission.
- `claim_next/3`: race-safe single filtered bulk UPDATE (two providers cannot win one epoch).
- `close/4` head-verify: matching final_head seals `:alive` with `head_verified=true`; **forged final_head downgrades to `:build_broken`** (the `XAAS_LEASE_CLOSE head mismatch` warning in the log is this negative test firing); unverifiable (no worktree) downgrades to `:partial_alive` with `verifier_unavailable` evidence.
- `refuse/3`: typed refusal → epoch `:failed`, receipt `:refused` with `refusal_reason`.
- EpochReactor provider-pull semantics: running provider epoch awaits its provider, never auto-completes.

`test/xaas_web/execution_fabric_controller_test.exs` — 13 tests, the /internal-api/execution transport:
- Fail-closed token gate: **unset INTERNAL_API_TOKEN → 503 on every request; wrong bearer → 401**.
- Hooks: pre_tool_use without a lease → typed **403 deny**; stop without a lease → `not_closeable` (never closure); unknown hook → 404; session_start acknowledged.
- MCP JSON-RPC surface + full provider-pull loop over real rows (claim → admit → construct → close, real DB).
- Drift-added atom-safety test (see inventory) — green.

`test/xaas/actuation_test.exs` — 4 tests, the control plane:
- every provider semantic IRI admitted from public ontologies;
- **Reactor is the admitted DO path and replay does not repeat the mutation** (idempotent replay through `Xaas.Actuation.run/4` admit→do→receipt inside the Ash data-layer transaction);
- replay returns a real dot-accessible resource, not a frozen JSON snapshot;
- **idempotency-key reuse with a different consequence is refused** (`{:idempotency_conflict, key}` surfaced unwrapped).

`lib/xaas/actuation.ex` read-verified: delegated actuation (`authorize?: false`) without authority evidence is refused (`:delegated_actuation_requires_authority_evidence`); mutation cannot commit ahead of its receipt (transaction-wrapped Reactor, sync-forced).

## Classification
Build not broken (compile exit 0), no blockers (Postgres up, dev :4000 server untouched, SQL Sandbox tests green), nothing unsupported. Boundary `owns`: actuation admit→do→receipt, lease admission court, epoch loop — all verified by execution this session. → **qualified**.

## Repairs / alternates
None required — zero failures anywhere. No repair branch cut (`fix/xaas-v26.9.17-boundary` not needed). The atom-safety drift on the controller is reported above for whoever owns that seam to commit; it is lawful, tested, and outside the sibling's file set.

## Falsifiers attempted
1. Force compile under warnings-as-errors (falsify "build broken") — survived.
2. Epoch-loop-only suite (`--only ultracode`) — survived 8/0.
3. Full-suite regression gate — survived 648/0.
4. Targeted court probes — survived 30/0, including negative paths (forged head, unknown tool class, missing lease/token, idempotency conflict, attacker reason string).

## What the operator did NOT have to write
Everything: zero product files written by this agent (0 hand-written lines on 産面). Only this receipt in /tmp/uzc. All verification executed against the exact pinned subject with the required verifiers, in this session.
