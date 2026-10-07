# W174 — Ontop health-check typing (config-gated)

backfilled by coordinator from lane completion report

## Subject

- Lane: W174, batch 3, v26.10.6 convergence, repo /Users/sac/xaas

## Change

`check_ontop/0` is now config-gated on `:xaas, :ontop_endpoint`:

- config absent → check is skipped / reported not_configured; health aggregate
  still ok
- config present but endpoint down → 503 exactly as before (unchanged)

`config/config.exs` carries a commented gated line documenting the key.

## Courts

- health tests: 7/7 passed, including a new unconfigured-returns-200 court
- native run: GET /internal-api/health → 200 with ontop skipped

W173's unconfigured-endpoint 503 class is gone.

## Standing

ALIVE (narrow) — verified via health test suite + native HTTP GET.

## W310h aggregate fix

Observed (W310g, deterministic x3 on a fresh properly-booted server):
`GET /internal-api/health` returned 503 while the auth gate, repo, Ontop
(config-gated skip) and all 7 `ash_domain:*` counts were ok/skipped -- the
failing sub-check was `ultracode_tick`: `last_tick_at` 22:36Z, elapsed
19.5 min against a 5-minute staleness window, on a server up for <1 min.
Direct Postgres check of `oban_jobs` showed the `:tick` cron healthy
(job 28635 completed at 22:56Z, one minute after boot) -- the check was
counting PRE-BOOT tick history against the staleness window, so any
freshly-booted server checked within the first post-boot cron minute
(after >=5 min of downtime) failed deterministically. Classification:
warmup-window typing bug in the check, not a liveness regression.

Fix (`lib/xaas_web/controllers/health_controller.ex`):
`check_ultracode_tick/0` now derives the node's real boot instant from
`:erlang.statistics(:wall_clock)` (no new child, no new config key) and
distinguishes three states:

- last tick POST-boot and fresh -> ok (unchanged)
- last tick POST-boot but stale -> error (unchanged; live cron died)
- last tick PRE-boot or nil -> `skipped (:warming_up)` with typed fields
  (`reason`, `last_tick_at`, `node_boot_at`, `warmup_until`) while
  `now < boot + stale_after_minutes + 2` -- per W174's own law
  (unconfigured/no-opportunity != down); past the grace window with still
  no post-boot tick, back to a real error ("the :tick cron appears dead,
  not just warming up"), preserving TickHealth's "silence is not liveness"
  outside the boot window. Test-only seam
  `config :xaas, :health_node_boot_at_override` makes the post-grace
  branch deterministically exercisable.

Supporting fix in `timed/1`: a `{:skipped, map}` payload now merges to
top level (same shape as `{:ok, extra}`); bare atoms keep the
`reason:` wrap (ontop's `{:skipped, :not_configured}` unchanged).

Courts (real output):
- `MIX_ENV=test mix test test/xaas_web/controllers/health_controller_test.exs`
  -> 8 passed (0 failed), incl. two new/rewritten courts: warming-up
  returns 200 + `skipped :warming_up`; boot-seam past grace window
  returns 503 + "since node boot".
- Fresh-boot native run (kill ALL beams -> committed boot chain ->
  root poll 200): `curl /internal-api/health` x3 -> HTTP 200 x3,
  `ultracode_tick` = `skipped :warming_up` (last_tick 22:59:00Z pre-boot,
  boot 22:59:19Z), all other checks ok/skipped, aggregate ok.
- No mock gate change: no mocking libraries introduced; tick evidence is
  real `%Oban.Job{}` rows, boot time is real `:erlang.statistics/2`.

Standing: ALIVE (narrow) -- aggregate 200 deterministic x3 on a fresh
properly-booted server; post-grace dead-cron 503 verified in test.

## W311 confirmations (integration lane W311, v26.10.6)

Real output, fresh boot via the committed chain (global-setup + PHX_SERVER
+ `mix run --no-halt` + health poll), all beams on :4000 cleared first:

1. Playwright target spec:
   `PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token npx
   playwright test e2e/internal-api.spec.cjs`
   -> `4 passed (17.0s)` (4/4: token-gate suite incl. real health data
   and real OCEL summary data with the env token). The prior W310g
   failure does not reproduce on a fresh boot.

2. Full web suite:
   `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web`
   -> `356 passed, 1 excluded` (0 failures). Note: this exceeds the
   stated 352 target — 4 additional tests are present on the tree
   beyond the 351+W270-SSE baseline (other lanes' landed tests), not a
   discrepancy in this run.

Server killed after; port :4000 confirmed clear.
