# Boundary receipt — qualify-boundary(ggen_igniter, cap-framework-projection)

- Date: 2026-09-16 (wave v26.9.17), agent 5/10 (retry spawn)
- Pinned HEAD: `d018ed4b407b6e3d0ed747e7076fe55f0c254804` on `feat/calver-ticket-day-pack`
- Drift: NONE at re-pin; HEAD + clean tree re-verified AFTER the full suite (tests dirtied nothing tracked)
- Standing: **ALIVE** (FOND: **qualified**)
- Repairs: NONE required — no fix branch, no commits, no lawful alternate needed

## Court (discovered from .github/workflows/ci.yml + mix.exs)

CI gates: deps.get → format --check-formatted → credo → mix compile (dev) → mix test.
Executed locally in mandated form (see below). Env: elixir 1.18.4-otp-27 (matches CI pin);
`~/ex4pm` fixture present with pinned `725f495^` reachable (`git cat-file -e` OK); `ggen` CLI
present at /opt/homebrew/bin/ggen (so CI-installed-CLI-only tests ran for real, not skipped).

## Commands + exits

1. `git rev-parse HEAD` → `d018ed4b407b6e3d0ed747e7076fe55f0c254804`, clean. PIN CONFIRMED.
2. `mix deps.get` → completed, "All dependencies are up to date" (hex advisory notices printed; informational).
3. `mix compile --force --warnings-as-errors` → **EXIT=0**, zero warnings (rustler NIF `ggen_graph_nif` compiled, cargo cache warm).
4. `mix test` → **"20 doctests, 42 properties, 932 tests, 0 failures, 9 excluded, 1 skipped"** in 584.5s
   (excluded = named `:requires_qlever_server` / `:requires_ash_r2rml` gates per test/test_helper.exs;
   skipped = one documented `@tag skip` at test/ggen_igniter_ash_install_alignment_test.exs:437
   "requires a real deps fetch, not reachable in test mode"; ExUnit halts non-zero on any failure).

## Capability evidence (owns: framework projection is REAL here)

- `mix ggen_igniter.sync` surface: lib/mix/tasks/ggen_igniter.sync.ex:207 `use Igniter.Mix.Task`;
  :215 `@impl Igniter.Mix.Task info/2` with schema incl. `for_each`, `dry_run`, `manifest_dir`,
  `on_stale`, `verify_cwd`, `skip_if`, `unless_exists` (project-aware, reconciliation-manifest-aware).
  Sibling tasks: doctor.ex:135, plan.ex:107, fortune5_ready.ex:83, install.ex:88.
- `Igniter.compose_task/4`: deps/igniter/lib/igniter.ex:479 `compose_task(igniter, task, argv \\ nil, fallback \\ nil)`;
  exercised against REAL Ash generators (`ash.install`, `ash_postgres.install`, `ash.gen.resource`,
  `ash.gen.custom_expression`) via Igniter.Test in test/ggen_igniter_ash_install_alignment_test.exs:89,160,282,
  test/ggen_igniter_ash_gen_support_alignment_test.exs:88,107,152, test/ggen_igniter_agent_guard_test.exs:270 —
  all ran green in this session's suite.
- calver-ticket-day-pack family: priv/ggen/calver-ticket-day-pack/ = ontology.ttl (public vocabulary:
  oslc_cm:ChangeRequest, prov:Activity, earl, dcterms, APS individuals; no custom namespace) + gates/
  (010_contract.rq, 020_day.rq, 030_tickets.rq) + templates/ (ticket.md.eex, runbook.md.eex, runlog.md.eex).
  14 packs under priv/ggen/. No pack.toml under priv/ggen/* — admission artifacts live in the marketplace
  repo (out of this boundary), consistent across all 14 packs.
- Multi-file fan-out `--for-each`: covered by 14 test files (e.g. test/ggen_igniter_sync_dry_run_test.exs:154-180).
- Write-safety observed live in the run log: redteam duplicate-output-path fixtures refused
  ("refused: duplicate output path(s)"; SilentLastWriterWins=0/11) — actuation gate works.

## Falsifiers attempted

1. `--warnings-as-errors` force-compile → no warning survived.
2. Full 932-test suite incl. real subprocess `mix ggen_igniter.*` e2e and shellout tests → 0 failures.
3. Capability existence by reading code, not trusting docs → confirmed with file:line above.
4. Fixture/CLI preconditions independently verified (ex4pm commit, ggen binary, toolchain version).
5. Post-suite `git status --porcelain` → empty (no uncommitted drift; HEAD re-read → same SHA).

## Ledger / ratio

Hand-written lines on 産面 this task: 0. Verification 100% manufactured by the repo's own court.
Operator did NOT have to write: any verification command, any repair, any test, any capability code —
the boundary qualified from the pinned tree as-is. Receipt is the sole artifact, written to /tmp (not the repo).

## Constraint compliance

No push/PR/merge; this repo only; no generators run against consumer repos (Igniter.Test in-memory only, via suite);
no secrets printed; node_modules/_build/deps ignored for inspection.
