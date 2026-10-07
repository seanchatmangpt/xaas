# W982g — L-estimate spec wave receipt

Lane W982g, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`
(HEAD at lane open: `6f235905`). No commit made, per lane contract. Standing:
**ALIVE** (one L-estimate spec implemented, court green ×2 on a fresh-cold lane
build root, mutation kill witnessed).

## Selection history (stop-and-disclose)

Backlog at lane open (post-W969f, L-estimate remainder SPEC-08/32/34; SPEC-10
excluded as another lane's in-flight surface):

| spec | disposition |
|---|---|
| SPEC-08 | LANE-HOT: W975b's SPEC-07 multitenancy diff is still uncommitted on the
  billing tree (`lib/xaas/billing/approval_{pricing,quota,tier}_*.ex`,
  `approval_invoice_reconciliation_approve.ex` modified; migration
  `20261007250000_add_org_id_to_billing_approval_tables.exs` untracked) — the
  money-mover files SPEC-08 must retrofit are inside that in-flight diff |
| SPEC-32 | ALREADY-LANDED: option (b) projection exists at HEAD —
  `lib/xaas_web/controllers/execution_fabric_controller.ex`
  `format_actuation/2` projects `{status, replay, intent_id, receipt_id}` →
  `{target: "quiescent", already_stopped}` additive envelope (commit
  `9f1247c1`, W840/W824/W844), fenced by
  `test/xaas_web/quiescent_fabric_tie_test.exs` (envelope + replayed-idempotency
  blocks green at HEAD). Spec amendment: nothing to add; typed disclosure, not
  forced |
| SPEC-34 | LANE-FREE, dependency satisfied (row 33 sha256-map landed by W852) | **PICKED** |

## What landed (SPEC-34 — CI/regen drift leg for generated surfaces)

- `lib/xaas/generated/regen_check.ex` — `Xaas.Generated.RegenCheck`: the leg.
  11-surface census aligned 1:1 with `registry_drift_guard_test.exs`'s
  `@regen_commands` (10, W852 state) + the two ash_typescript artifacts
  (W837 court). Per surface: `:ggen_igniter_check` (REAL subprocess
  `mix ggen_igniter.sync ... --check --json --on-stale preserve`, exit-code
  contract per `GgenIgniter.TaskContract`: 0 clean / 4 drift),
  `:byte_compare` (real `mix ash_typescript.codegen --output <tmp>` +
  byte equality), or typed `:disclosed_skip`. `clean?/1` = no `{:drift, _}`
  (typed UNSUPPORTED skips never fail the leg); exit codes 0/4 per the
  TaskContract drift vocabulary.
- `lib/mix/tasks/xaas.generated.regen_check.ex` — `mix xaas.generated.regen_check`
  (`--json` envelope; human report; exit 0/4). CI-invocable.
- `test/xaas/generated/regen_check_court_test.exs` — 4-test Chicago court.
- `.github/workflows/ci_cd.yaml` — `ci` job step "Generated-surface regen drift
  check" (`mix xaas.generated.regen_check`), the CI leg the registry guard's
  header deferred to ("CI/regen leg, P2-2").

### Leg verdict at HEAD (witnessed 2026-10-07, lane build root fresh-cold)

- DRIFT-CHECKED (clean regen proven): `lib/xaas/generated/zcode_event_registry.ex`
  (4 queries, 63 rows), `lib/xaas/telemetry/ocel_envelope.ex` (1 query, 4 rows)
  via real `--check --json` → exit 0, "planned: skip (unchanged)";
  `assets/js/ash_rpc.ts` + `assets/js/ash_types.ts` byte-identical to a fresh
  codegen run, deterministic ×2.
- Typed disclosed skips (8): sa2a×3 + castle×2 (`UNSUPPORTED(regen-toolchain-external)`),
  `mcp_scope.ex` (`UNSUPPORTED(regen-command-not-in-repo)`),
  and two **new real findings** (below).

### New findings (real drift / broken generators, disclosed not forced)

1. `lib/mix/tasks/xaas.library.manufacture.ex`:
   **UNSUPPORTED(renderer-escape-bug)** — the surface HAS genuinely drifted
   (`--check` exit 4, drift set = the task file) — the first witnessed real kill
   of the leg — but re-running the named regen emits invalid Elixir (escaped
   quotes: `table \"library_books\"` inside the emitted DSL) and would clobber
   hand-authored policy (deny-by-default `actor_present` write floor). I ran the
   real regen once, inspected the diff, and restored the tracked bytes
   byte-identical (md5 verified). Repair is upstream (template/ontology), not a
   lane-local patch.
2. `lib/xaas/generated/capital_census/facts.ex`:
   **UNSUPPORTED(renderer-compile-error)** — the pinned `--template` stem does
   not resolve under `--pack-dir` (resolved against cwd), and with explicit
   `--query facts/g_table/frontier_outcomes` + repo-relative template the render
   fails with `CompileError (nofile)`. Not regen-invocable at the bound
   ggen_igniter version.

Both remain covered by their sha256 hand-edit pins (registry guard).

### Notes on the census seams

- The zcode/telemetry packs keep queries under `queries/` (the generator
  discovers `gates/*.rq`), so the census passes explicit `--query name=path.rq`
  flags — the registry guard's pinned one-line regen commands do NOT run as
  written (same SYNC_REFUSED both surfaces).
- `--on-stale preserve` is passed on `--check` runs: the zcode pack carries a
  recorded prior-run output path under a foreign worktree root
  (`worktrees/sjira/sj-002/...`), which otherwise REFUSES the check outright.

## Court (mutation kill)

`test/xaas/generated/regen_check_court_test.exs`, 4 tests:
1. ggen_igniter surfaces clean via the generator's own `--check` contract (×2
   surfaces asserted == :ok).
2. ash_typescript byte-compare green and deterministic across two fresh runs.
3. **MUTATION KILL**: injected hand-edit (one-line prefix injected into a temp
   copy of `assets/js/ash_types.ts`, `:tracked_root` seam) → verdict flips to
   `{:drift, detail}` naming DRIFT_SURFACE_STALE / path / repair regen command;
   tracked tree untouched. Plus the un-injected real kill witnessed in finding 1
   (library.manufacture --check exit 4).
4. census completeness: 11 surfaces = 3 executable + 8 typed skips; every skip
   reason carries `UNSUPPORTED(`; skips do not fail the leg.

## Verification ladder (real runs)

Env: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982g`
(fresh-cold root; `asdf install` + `mix deps.get` then cold compile, exit 0).

1. `mix compile --warnings-as-errors` → exit 0 ("Compiling xaas ... Generated").
2. Court run 1: `mix test test/xaas/generated/regen_check_court_test.exs` →
   **4 passed**, 48.0s, exit 0.
3. Court run 2 (post `clean?/1` fix): **4 passed**, exit 0.
4. `mix xaas.generated.regen_check` → full human report (2 OK + ash OK + 8 SKIP,
   exit 0 post-fix). First task run witnessed the `clean?/1` skip-handling bug
   (exit 4 on an all-OK report) — fixed in-lane, court amended to fence the
   skip≠drift semantics.
5. Smoke tails (real, in receipt body above): zcode --check exit 0 JSON
   (drifted_count 0), ocel_envelope exit 0 (4 rows), library pack exit 4
   (drift set = the task file), facts.ex REFUSED(CompileError).

Pre-existing (not session-introduced): AshAffidavit `@envelope_domain_tag`
compile warning; PromEx/Grafana nxdomain noise; `/` at 87% capacity (1.8 Gi
free — this lane's cold build ran, but disk is tight for the next cold-root
lane).

## Standing

SPEC-34: **ALIVE** (implemented, court green ×2, mutation kill witnessed ×2 —
synthetic injected hand-edit + the witnessed library.manufacture drift).
SPEC-32: **ALREADY-LANDED at HEAD** (typed disclosure; no change made).
SPEC-08: **BLOCKED(lane-hot)** — W975b's uncommitted billing diff owns the
surface. `_build-laneW982g` deleted at integration, per lane-lease law.

---

## Triage addendum (W983c, 2026-10-07 — supersedes the two UNSUPPORTED findings above)

Full receipt: `docs/sjira/v26.10.6/plans/w983c-regen-renderer-triage.md`. All
tails re-witnessed live at ggen_igniter 26.10.1, pinned toolchain.

1. **library.manufacture `UNSUPPORTED(renderer-escape-bug)` — REFUTED, typed
   correction.** The full real regen output parses as valid Elixir
   (`Code.string_to_quoted` OK); the `\"` text is the template's correct
   heredoc-internal escaping, not invalid emitted Elixir — the "escape bug"
   was a misread of git-diff rendering. Locus: LOCAL. The real, witnessed
   drift is a policy-floor delta: the tracked task file emits
   `authorize_if always()` write policies (0 `actor_present`); the
   ontology-backed render emits the deny-by-default `actor_present()` floor
   at 4 sites — regen would STRENGTHEN policy, not clobber it (nothing to
   clobber). Unblock (owner decision, actuation-ready): run the regen,
   re-pin the guard sha256, retire the skip. Corrected annotation:
   `BLOCKED(policy-floor-upgrade-pending)`.
2. **capital_census/facts.ex `UNSUPPORTED(renderer-compile-error)` — LOCUS
   CORRECTED to LOCAL.** Not a renderer defect: the renderer is plain
   `EEx.eval_string`. Minimal repro = the missing 4th `--query`
   (`facts_spec.rq` → bare `recurrence_threshold` binding): its absence gives
   `error: undefined variable "recurrence_threshold"` → `CompileError{file:
   "nofile"}`. With all four queries the render is byte-identical to the
   tracked file. Corrected command (witnessed) in the W983c receipt; the
   surface is regen-invocable and should become a `:ggen_igniter_check`
   census entry. Corrected annotation: skip reason retired.
3. **Registry guard pins — all defect pins witnessed failing; corrected
   commands witnessed working.** zcode/telemetry: `ArgumentError: no *.rq
   files found in <pack>/gates/` (discovery is gates/-only; these packs keep
   queries under `queries/`), plus `SYNC_REFUSED` on the stale foreign
   worktree path without `--on-stale preserve`; census: template resolved
   against cwd → file-not-found. Corrected one-line commands per surface in
   the W983c receipt. Locus: LOCAL — fix the pins in
   `test/xaas/generated/registry_drift_guard_test.exs`.

**Net: zero upstream (ggen_igniter) findings warrant filing; all three
boundaries are consumer-local.** The two typed-UNSUPPORTED annotations above
this addendum are superseded by the corrected loci. Lane note: W983c's scratch
runs touched `.ggen_igniter/manifest.json`; repaired byte-identical to HEAD
(`REPAIRED(manifest-restored-to-HEAD)`, disclosed in the W983c receipt).
