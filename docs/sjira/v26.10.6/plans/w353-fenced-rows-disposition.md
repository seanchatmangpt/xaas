# W353 — §1 fenced rows: typed dispositions

Lane W353, repo /Users/sac/xaas @ feat/playwright-surface @ d1db2b03. Read-only evidence pass; no lib/ edits.

---

## Row #7 — capability_liveness_receipt.ex Monitor step unscheduled

**DISPOSITION: PERMANENT-FENCE** (unscheduled Monitor is the correct permanent posture; a cron is actively wrong today)

**Evidence**:

- `lib/xaas/operations/capability_liveness_receipt.ex` lines 39–44 state the design reason explicitly: the resource "Deliberately does NOT schedule the Monitor/ingest step itself — that depends on `weaver-live-matrix.sh`'s real receipt.jsonl file existing at a real path this resource has no business assuming, so fabricating a periodic ingest would risk silently ingesting a stale or missing file."
- Receipt-path convention is real and fail-closed: the ingest task (`lib/mix/tasks/xaas.ingest_capability_receipts.ex`) defaults to `../chatman-ecosystem/target/weaver-live/receipt.jsonl` and `Mix.raise`s ("No receipt file at ... run weaver-live-matrix.sh first") when absent — no silent-stale ingest path exists.
- Ingest task call sites (grounding the "on-demand" claim; no cron, no CI):
  - `test/mix/tasks/xaas_ingest_capability_receipts_test.exs` — real test coverage of the task.
  - `mix.exs:282` — comment-only mention among verify_and_commit tooling; greps of `.github/` and `scripts/` for the task name: zero hits.
  - Docs prescribing manual invocation: `docs/claude/diataxis/tutorials/build-an-autonomic-capability-loop.md`, `docs/claude/diataxis/reference/http-api-surface.md`, `docs/sjira/v26.10.6/plans/w338-plan-residual-rows.md`, `w337-ash-policy-floor.md`, `_CLOSURE_PLAN.md`.
- The Analyze half of the MAPE-K loop IS scheduled: `schedule :check_regressions, "*/15 * * * *"` (line 47) runs every 15 min as the `:oban_scheduler` system actor through the `Xaas.Checks.SystemActor` policy. Only ingest is manual.

**Rationale**: the Monitor input is an artifact owned by the sibling chatman-ecosystem repo that xaas cannot schedule or validate; a cron pulling a stale/missing sibling artifact would fabricate loop closure. Fail-closed `Mix.raise` + idempotent `(capability, subject)` upsert make on-demand ingest the honest boundary, matching the resource's own moduledoc.

**Reopen condition**: a real CI stage invoking `mix xaas.ingest_capability_receipts` after `weaver-live-matrix.sh`, or a documented cross-repo receipt-path convention. Until then: fence.

---

## Row #8 — Code.ensure_loaded? soft-gates

**DISPOSITION: RESOLVE-BY-TEST** — the guarded modules are core own modules that landed in-tree; pin their presence with a named test so the soft-gate fallback branches become provably dead.

**Evidence**:

- The three sites and what each loads:
  - `lib/xaas_web/live/system/command_center_adapter.ex:81` — `Code.ensure_loaded?(Xaas.Chicago)` + `function_exported?(Xaas.Chicago, :layers, 0)` guards `Xaas.Chicago.subject/0, layers/0, cases/0`.
  - `lib/xaas_web/live/chicago/drill_down_live.ex:68` — `Code.ensure_loaded?(Xaas.Chicago.View)` + `function_exported?(..., :drill_down, 0)` guards `Xaas.Chicago.View.drill_down/0`.
  - `lib/xaas_web/live/chicago/drill_down_live.ex:408` — `Code.ensure_loaded?(Xaas.Chicago)` + `function_exported?(..., :subject, 0)` in `refused_subject/0`.
- Module existence verified — core own modules, same OTP app:
  - `lib/xaas/chicago.ex` — `defmodule Xaas.Chicago`
  - `lib/xaas/chicago/view.ex` — `defmodule Xaas.Chicago.View`
- Deciding fact: absence is a hidden failure, not a degraded mode. Both adapters' moduledocs say "compile-safe while `Xaas.Chicago` has not landed (L4 owns it)" — that premise is STALE; the modules landed in-tree. Same-app modules cannot be absent at runtime without an upstream compile failure, which the build/test gate already catches.
- Supporting context: `test/xaas/chicago/**` suites exist (`negative_courts`, `bridges`, `consumer`, `seller`, `surface`); `test/xaas/chicago/surface/command_center_adapter_test.exs` already grep-gates the adapter; `test/xaas_web/live/chicago/drill_down_live_test.exs` drives `drill_down_episode/0`.

**Named test**: `test/xaas/chicago/presence_pin_test.exs`

```elixir
test "Xaas.Chicago projection surface is loaded and exported" do
  assert Code.ensure_loaded?(Xaas.Chicago)
  assert function_exported?(Xaas.Chicago, :subject, 0)
  assert function_exported?(Xaas.Chicago, :layers, 0)
  assert function_exported?(Xaas.Chicago, :cases, 0)
end

test "Xaas.Chicago.View drill_down surface is loaded and exported" do
  assert Code.ensure_loaded?(Xaas.Chicago.View)
  assert function_exported?(Xaas.Chicago.View, :drill_down, 0)
end
```

Note: `function_exported?/3` returns false for not-yet-loaded modules, so each assertion block asserts `Code.ensure_loaded?/1` first — the guards themselves perform the load, so at runtime the `{:refused, ...}` branches are unreachable unless the modules were removed.

**Falsifier**: delete/rename `lib/xaas/chicago.ex` → the pin test fails, forcing the guards to be revisited rather than silently degraded. If the modules are ever extracted to an external dep (out of the same app), this disposition flips to degraded-mode-legitimate and the guards become lawful again.

---

## Row #16 — priv/ontop/xaas-mapping.generated.ttl generator

**DISPOSITION: OPERATOR-DECISION** — delete vs adopt. Not PERMANENT-FENCE (the artifact is driftable with no producer, so "fence as permanent" just renames UNKNOWN without evidence); not RESOLVE-BY-TEST (no generator exists to test against).

**Re-verification (2026-10-06)**: re-ran the w85 sweep. Still zero producer references for `xaas-mapping.generated.ttl` in:

- repo-wide grep (lib/, config/, priv/, .github/, scripts/, mix.exs);
- `~/ash_surface` (repo exists; zero hits);
- `~/ggen-marketplace` (zero hits);
- git history: exactly one commit ever touched the file — `28936f48` "feat(library): manufacture Next Read recommendation engine and reader liveview via ggen_igniter" — manufactured once, never regenerated since.
- Prior agreeing evidence: `w85-mix-generator-parity.md` ("permanent-UNKNOWN", section #1), `vector4-gen-parity.md` ("no header, no workflow/mix task found"), `_CLOSURE_PLAN.md` row 16.

**Current file state**: `priv/ontop/xaas-mapping.generated.ttl` is valid R2RML (rr:TriplesMap rows over real xaas tables: `approval_cmek_key_bindings`, `castle_verb_inventory_goals`, ...; valid rr:logicalTable/rr:subjectMap/predicateObjectMap syntax). First line is a bare `@prefix rr:` — NO generator header, no provenance comment, no consumer in code (zero code references).

**The two options, crisply**:

- **Option A — adopt**: declare the file the authoritative source. Add a header comment naming it authoritative (at next regen per the row's original suggestion), optionally add a drift gate. UNKNOWN → ADOPTED with a named owner. Cost: one line + optional gate.
- **Option B — delete**: remove the file (and any doc references). No code reads it; if a real mapping need reappears, regenerate via a real generator (e.g. ash_r2rml at its pinned SHA). Cost: one commit. Benefit: kills the ungated orphan projection.

**Recommendation**: Option B (delete) is the cleaner default given zero code consumers; take Option A only if a consumer surfaces. Both are one-commit reversible — this is exactly an operator-level selection, not a lane-level fence.

---

## W353 receipt

- Exact subject: /Users/sac/xaas @ feat/playwright-surface @ d1db2b03 (uncommitted working tree; lane wrote only this plan file).
- Evidence commands: direct Reads of `capability_liveness_receipt.ex`, `xaas.ingest_capability_receipts.ex`, `command_center_adapter.ex`, `drill_down_live.ex` excerpts, ttl header; greps for `Code.ensure_loaded` (lib), ingest-task references (repo + .github + scripts + mix.exs), `xaas-mapping.generated` (repo + ~/ash_surface + ~/ggen-marketplace); `git log` on the ttl file.
- Transport failures: none (one zsh quoting retry on a grep pipeline).
- μ/diff: 1 file written (`docs/sjira/v26.10.6/plans/w353-fenced-rows-disposition.md`), handwritten; lib/ untouched per contract.
- Verification ladder: read-only disposition pass — every claim grounded in an inline-cited file read or grep; no test run required.
- Standing: PARTIAL — three typed disposition recommendations delivered (#7 PERMANENT-FENCE, #8 RESOLVE-BY-TEST with named pin test, #16 OPERATOR-DECISION); coordinator owns row closure.
