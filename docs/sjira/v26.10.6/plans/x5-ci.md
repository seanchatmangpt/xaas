# X5 — v26.10.5 CI Audit + Wiring-Gate Plan

Lane X5, 2026-10-06. Sources: local `.github/workflows` listings + `gh run list --limit 5`
per repo (gh authed as `seanchatmangpt`). Read-only audit; no git mutations performed.

## Per-repo status

### xaas (21 workflows)
Workflows: `ci_cd.yaml`, `cold-court.yml`, `fly_deploy.yaml`, `packer.yaml`,
`semantic-crown.yml`, `release-sync-v26.9.28.yml`, `release-tag-v26.9.28.yml`,
`claude-daily-drain.yml`, `castle-paas-bridge.yml`, `factory-b-failure-immunity.yml`,
`project-measure-extension.yml`, `r79/r80/r81/r84*.yml`, `sa2a-computation-crown.yml`,
`stogaf-wd-cs2-court.yml`, `ultracode-closure.yml`, `wd-cs2-exact-head.yml`,
`wd-deck-generation.yml`.
Recent runs: `v26.9.28 lock sync` SUCCESS (recurring schedule, latest 37502801141);
`WD CS2 exact-head court` FAILURE (37461512895, schedule, 2026-10-06);
`Claude daily backlog drain` FAILURE (37430446903).
Release gate: `ci_cd.yaml` green on release head; lock-sync/release workflows currently
pinned to v26.9.28 — v26.10.5 needs new/updated sync+tag workflows (UNKNOWN whether
v26.10.5 variants exist yet; not in listing above).

### ash_surface (5 workflows)
`ci.yml`, `dialyzer-coverage.yml`, `manufacture.yml`, `release.yml`, `security.yml`.
Recent: `Security` FAILURE on schedule 37460405771 (2026-10-06) after a SUCCESS run
37308467365 on 10-05 — intermittent/depping; Dependabot updates all SUCCESS.
Release gate: `ci.yml` + `manufacture.yml` + `release.yml` green; investigate
`security.yml` schedule failure (20s runtime suggests config/cred-data error, not scan finding — UNKNOWN root cause, not inspected).

### ggen (80+ workflows)
Core: `ci.yml`, `quality.yml`, `ggen-self-host.yml`, `ggen-sync-run.yml`,
`publish-candidate.yml`, `publish-registry.yml`, `release.yml`, `scorecard.yml`.
Recent: OpenSSF Scorecard SUCCESS; Architecture Autonomics SUCCESS; Dependabot hex
updates FAILING in `/crates/tai-erlang-autonomics` + `/crates/tps-jidoka`; Self-Host
Observer SUCCESS on a dependabot cargo PR.
Release gate: `ci.yml` + `ggen-self-host.yml` + `publish-registry.yml` green on the
v26.10.5 tag. Scorecard green (already is).

### ggen-marketplace (27 workflows)
Recent: `Source correspondence` FAILURE (37501609969, 2026-10-06, latest of 2 consecutive
failures), `CI` FAILURE (37449121386, 8m25s, 2026-10-06). Scorecard SUCCESS.
Release gate: `ci.yml` and `source-correspondence.yml` MUST be green — marketplace is the
selection authority (`marketplace.active.toml`); a red source-correspondence court means
pack/ontology drift that v26.10.5 would inherit. Both currently RED.

### ggen_igniter (4 workflows)
`ci.yml` plus small court workflows. Recent: `ggen_igniter CI` FAILURE on BOTH `main` and
tag `v26.10.5` pushes (37106771689 / 37106771985, 2026-10-03). Failure point observed via
`gh run view 37106771689`: `mix credo` step X in "Build + format + credo + verify";
`mix compile` and `mix ggen_igniter.verify` (fail-CLOSED pack check) never reached.
v26.10.3/v26.10.4 tag pushes also failed. **ggen_igniter has no green release run in the
visible window — this is the primary v26.10.5 blocker.** Gate: fix credo, then full CI
job (compile + fail-closed verify + test shards) green on the v26.10.5 tag.

### ash_a2a (13 workflows)
Recent: v26.10.4 release push — `CI` FAILURE (25m55s), `GALL-003 Command Authority Court`
FAILURE, Scorecard SUCCESS. Scheduled `Flake hunt` FAILURE (52m49s, possibly by design —
flake hunts are expected to find flakes; UNKNOWN whether failure is court-verdict or
infra). `SA2A conformance receipts` scheduled FAILURE.
Release gate: `ci.yml` + `sa2a-conformance.yml` + `release.yml` green on v26.10.5 head.
Currently CI is red on the v26.10.4 release commit — must be triaged before v26.10.5.

### ash_pplan (1 workflow: `ci.yml`)
Recent: CI FAILURE 3 consecutive (schedule + 2 pushes, ~45m each). Observed via
`gh run view 37308911349`: job `semantic (pinned ggen-ecosystem)` fails at "Parse
canonical ontology in ggen-ecosystem" (20s); jobs `elixir (floor)` and `elixir (current)`
also X. Gate: `ci.yml` all three jobs green. The pinned-ggen-ecosystem ontology-parse
failure suggests upstream ggen-ecosystem drift, not local code.

### ferroplan (10 workflows)
Recent: `CI` FAILURE on last 3 pushes (27m, 29m, 8m runs); `Pages` SUCCESS.
Release gate: `ci.yml` + `validate-all-code.yml` green. Pages is docs, not a release gate.

### zcode-cli (5 workflows)
`ci.yml`, `prepare-release.yml`, `publish.yml`, `release-commit.yml`, `gall-006`.
Recent: `Prepare ZCode CLI release` FAILURE 5 consecutive scheduled runs (10-01 → 10-05,
5–7m each) — persistent, not flaky. Base `ci.yml` status UNKNOWN (no recent runs visible
in top-5; last activity was scheduled prepare-release). Gate: `ci.yml` green +
prepare-release fixed (5 consecutive failures = broken wiring, likely stale secret or
version drift).

### gymact (55+ workflows)
Recent activity is all on a dependabot PR (2026-10-01): mixed — Federated Capability
Owner SUCCESS, several explore-courts SUCCESS, `Platform-console current-contract court`
FAILURE. No `ci.yml` runs on main visible in top-5 → main-branch CI status UNKNOWN.
Gate: `ci.yml` green on main; platform-console court failure on PRs to be triaged.

### beam4pm (20 workflows)
Recent: `v26.10.1 Hex release` FAILURE (372pm schedule, latest 37502383233, 2026-10-06) and
`v26.9.29 Hex release` FAILURE — both scheduled release workflows failing repeatedly at
~30s (looks like wiring/secret failure, not build). Scorecard SUCCESS.
Gate: `beam4pm-ci.yml` green; the scheduled hex-release failures block any v26.10.5 hex
publish from this repo until fixed (33s/22s runtime = early-exit, UNKNOWN exact cause).

### wasm4pm (24 workflows)
Recent: `CI` FAILURE on dependabot PRs (cargo `anyhow` bump 17m44s run, production-deps
group 21m49s). `InterviewAssist direct wpm court` SUCCESS on same PRs. Main-branch CI
status UNKNOWN (no main runs in top-5).
Gate: `ci.yml` green on the release head; the cargo/deps CI failures are on dependabot
branches, so may not block release — verify by running CI on the release head.

### autofde-lab (50+ workflows)
Note: default branch is `master`. Recent: `Phase H unattended trigger` FAILURE 5+
consecutive daily scheduled runs (~1m15s each — early-exit, looks like a precondition
refusal or missing input). Base `ci.yml` / `pr-ci.yml` status UNKNOWN from top-5.
Gate: `ci.yml` green; Phase H failure does not gate v26.10.5 (autonomous loop, not
release path) but is a standing red.

## Wiring-gate plan for v26.10.5

Order = dependency order (downstream repos inherit upstream pack/ontology health).

**Wave 1 — upstream authorities (block everything downstream):**
1. ggen: `ci.yml` + `ggen-self-host.yml` green on release SHA. Currently plausible-green
   (no core-CI failures observed); confirm by triggering on release head.
2. ggen-marketplace: fix `source-correspondence` (2 consecutive failures) and `CI`
   failure. This is the selection authority — do not release against a red court here.
3. ggen_igniter: fix `mix credo` failure, then full CI green on tag `v26.10.5`
   (compile + fail-closed `ggen_igniter.verify` + test shards). No green release run
   exists for v26.10.3–v26.10.5 — hard blocker.

**Wave 2 — consumers:**
4. ash_pplan: `ci.yml` 3 jobs green; start with the pinned ggen-ecosystem ontology-parse
   failure (likely resolves with Wave 1 fixes; re-run after Wave 1 lands).
5. ash_a2a: triage `CI` failure seen on v26.10.4 push; gate = `ci.yml` +
   `sa2a-conformance.yml` green on v26.10.5 head.
6. ash_surface: clear `security.yml` schedule failure; gate = `ci.yml` + `manufacture.yml`
   + `release.yml`.
7. ferroplan: `ci.yml` green (3 consecutive failures).
8. zcode-cli: fix `prepare-release.yml` (5 consecutive scheduled failures); confirm
   `ci.yml` runs on release head.

**Wave 3 — publish surfaces:**
9. beam4pm: fix scheduled hex-release workflows (both v26.9.29/v26.10.1 failing at ~30s)
   before attempting any v26.10.5 hex publish.
10. wasm4pm / gymact / xaas / autofde-lab: run core `ci.yml` on the v26.10.5 head to
    establish an observation (main-branch status currently UNKNOWN from run history);
    gymact platform-console court and autofde-lab Phase H are standing reds but not
    release-path gates.

**Cross-cutting gate rule:** release advances only when, for each repo in the dependency
chain, the workflows named above are green on the exact v26.10.5 head SHA — schedule-based
green does not count (operating doctrine: inspection != execution; ALIVE = observed
execution on the exact admitted subject).

## UNKNOWN list
- xaas: whether v26.10.5 sync/tag workflows exist (only v26.9.28 variants listed).
- ash_surface security.yml, zcode-cli prepare-release, beam4pm hex-release exact failure
  causes (not inspected — only conclusions + durations observed).
- gymact / wasm4pm / autofde-lab main-branch core-CI status (no main runs in visible
  window).
- ash_a2a flake-hunt failure class (by-design court verdict vs infra).
