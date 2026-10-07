# W702 — telemetry docs verification receipt

Lane W702, xaas v26.10.6. Subject: `feat/playwright-surface` @ a0723bf6.
Scope: verify every factual claim in
`docs/claude/diataxis/explanation/ocel-egress-forwarder.md` and
`docs/claude/diataxis/reference/ex4pm-ontology-pin.md` against real code.
Docs corrected in place; not committed (coordinator owns transitions).

## Method

Read every claimed module/path/config key in this repo and, where the
claim names a sibling-repo symbol, in `/Users/sac/ex4pm` directly.
One claim class got real *execution* evidence, not just reading: the
ontology pin (vendored file vs `git show pinned_sha:upstream_path`,
sha256 below).

## ocel-egress-forwarder.md

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| 1 | `Xaas.Telemetry.OcelForwarder` at `lib/xaas/telemetry/ocel_forwarder.ex` is the OCEL v2 egress | VERIFIED | lib/xaas/telemetry/ocel_forwarder.ex:1,74 |
| 2 | Called as second sink from `OcelAshEmitter.handle_event/4`, alongside durable NDJSON append to `priv/ocel/ash-actions.ndjson` | VERIFIED | lib/xaas/telemetry/ocel_ash_emitter.ex:334-337,193 |
| 3 | ex4pm has no HTTP ingress for beam4pm directly (sibling-repo behavior) | UNVERIFIABLE-from-xaas alone; consistent with absence of any ingest route in ex4pm router (only `/api/v1/ocel/events`, health routes) | /Users/sac/ex4pm/test/demo_web/lib/ex4pm_web/router.ex:19-27 |
| 4 | `Ex4pmWeb.OcelController.ingest/2` at `POST /api/v1/ocel/events` | VERIFIED (path corrected) | controller: `/Users/sac/ex4pm/test/demo_web/lib/ex4pm_web/controllers/ocel_controller.ex:1`; router: `post("/ocel/events")` under `scope "/api/v1"` (router.ex:22) — doc previously cited `/Users/sac/ex4pm/apps/ex4pm_web/...`, which does not exist |
| 5 | Controller calls `Ex4pm.Stream.Ingest.ingest_envelope/2`, which validates via `Ex4pm.OCEL.validate_envelope/1`, records evidence receipt, projects via `Ex4pm.Domain.Projector.project_log/1`, broadcasts on `"process_intelligence:live"` to `Ex4pmWeb.ProcessIntelligenceLive` | VERIFIED (paths corrected: `apps/ex4pm_stream`/`apps/ex4pm_core` → repo-root `lib/`) | /Users/sac/ex4pm/lib/ex4pm/stream/ingest.ex:19; /Users/sac/ex4pm/lib/ex4pm/ocel.ex:415; controller broadcaster calls `Projector.project_log/1` + `"process_intelligence:live"` (ocel_controller.ex:11,16,37); /Users/sac/ex4pm/lib/ex4pm/domain/projector.ex; live view at test/demo_web/lib/ex4pm_web/live/process_intelligence_live.ex |
| 6 | Envelope requires `"schema"` non-nil, `"producer"` map, `"sequence"` non-negative integer, `"events"` list/map; `"objects"`/`"object_relationships"` optional | VERIFIED | vendored validator lib/ex4pm/ocel.ex:361-414 (via priv/vendor/ex4pm/ocel.ex:361-414); producer agent_id/run_id: ingest.ex:87-88 |
| 7 | xaas "only builds the envelope shape and POSTs it" / "does not reimplement OCEL validation" | CORRECTED | ocel_forwarder.ex:149-160 — forwarder now calls the real `Ex4pm.OCEL.validate_envelope/1` (pinned git dep) before POSTing and refuses on `{:error, reason}`; doc rewritten to state pre-POST validation; "does not reimplement" claim kept true, clarified |
| 8 | xaas per-event shape is `"ocel:eid"`/`"ocel:activity"`/`"ocel:timestamp"` forwarded unchanged | CORRECTED | ocel_ash_emitter.ex:473-498 — emitter now emits OCEL 2.0 plain keys (`"id"`/`"type"`/`"time"`/`"attributes"`/`"relationships"`); `normalize_event/2` alias list reads both families; doc rewritten |
| 9 | `OcelForwarder.forward/1` builds the envelope inline as the quoted literal | CORRECTED | ocel_forwarder.ex:136-142 — envelope construction now delegates to `Xaas.Telemetry.OcelEnvelope.build/3` (lib/xaas/telemetry/ocel_envelope.ex:51); doc rewritten, literal retained with attribution |
| 10 | `config :xaas, :ex4pm_ocel_ingest_url` via `EX4PM_OCEL_INGEST_URL` in runtime.exs; nil disables forwarding | VERIFIED | config/runtime.exs:158-165; ocel_forwarder.ex:75-77,207-209 |
| 11 | `:ex4pm_ocel_ingest_timeout_ms` via `EX4PM_OCEL_INGEST_TIMEOUT_MS`, default 2000, Req `receive_timeout` | VERIFIED | config/runtime.exs:164-165; ocel_forwarder.ex:172,211-213 |
| 12 | Req "already a transitive/direct dependency, backed by Finch; no new HTTP dependency" | CORRECTED (minor) | `{:req, "~> 0.5"}` is now a direct dep (mix.exs:215); `{:finch, "~> 0.13"}` mix.exs:170; doc reworded |
| 13 | Failure handling: non-fatal, non-2xx/transport/raise caught, `Logger.warning/1`, always returns `:ok` | VERIFIED | ocel_forwarder.ex:161-192 (rescue → Logger.warning → :ok; post_envelope all branches → :ok) |
| 14 | Downstream DFG/conformance/rf1/rf2 oracles are ex4pm/beam4pm's job | UNVERIFIABLE (beam4pm rust oracles; consistent with ex4pm layout) | not present anywhere in xaas lib/ (no DFG/conformance logic under lib/xaas/telemetry/) |
| 15 | Test is real Chicago-style: real Bandit server on loopback, real Plug.Router, no mocked HTTP | VERIFIED | test/xaas/telemetry/ocel_forwarder_test.exs:1-53 (Bandit port 0 + ThousandIsland.listener_info, real POST capture) |
| 16 | See-also: "no mix path/hex dependency on beam4pm/ex4pm exists" | CORRECTED | mix.exs:228-245 — `{:ex4pm, git: "https://github.com/seanchatmangpt/ex4pm.git", ...}` pinned git dep; doc rewritten; beam4pm still has no dep |

## ex4pm-ontology-pin.md

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| 17 | `config :xaas, :ex4pm_ontology_check` in config.exs pins repo_path/pinned_sha/upstream_path/vendored_path | VERIFIED | config/config.exs:77-82 |
| 18 | repo_path default `$EX4PM_REPO_PATH` or `~/ex4pm` | VERIFIED | config/config.exs:78 |
| 19 | Current pin: sha `ade25ed1...`, upstream `lib/ex4pm/ocel.ex`, vendored `priv/vendor/ex4pm/ocel.ex` | VERIFIED + executed | config.exs:79-81; real run: `git -C ~/ex4pm show ade25ed12e93f89e7a2e1490698f99ae4947d702:lib/ex4pm/ocel.ex \| shasum -a 256` = `ec075eb1c75d5235647498fd880eb23322721618c1328624689a86ddee0a9287`, byte-identical to `sha256sum priv/vendor/ex4pm/ocel.ex` — pin is currently intact (note: ex4pm working-tree HEAD is 46bfcc8f..., newer than the pin; pin semantics unaffected) |
| 20 | Update procedure (status --porcelain, rev-parse, `git show <sha>:<path> > vendored`, config+file in one commit) | VERIFIED | matches `Xaas.Ontology.Ex4pmStaleness` git-show compare semantics; config.exs:75-76 points the mix task/doc at this file |
| 21 | Non-goals: byte-identical SHA-256 only; no semantic-diff, renames, LFS/gitlink/symlink handling, lineage check | VERIFIED | lib/xaas/ontology/ex4pm_staleness.ex:26-41,114-133 |
| 22 | Mix task exits 0 `OK:` on match; exits 0 `UNSUPPORTED (skipped)` when repo absent/unreachable; non-zero with named remediation only when present+divergent | VERIFIED | lib/mix/tasks/xaas.telemetry.check_ontology_staleness.ex:29-44 (skip → Mix.shell().info, no raise; error → Mix.raise) |
| 23 | ExUnit test tagged `:external`, excluded by default, `mix test --include external` | VERIFIED | test/xaas/ontology/ex4pm_staleness_test.exs:10,22 |
| 24 | Module paths: lib/xaas/ontology/ex4pm_staleness.ex, lib/mix/tasks/xaas.telemetry.check_ontology_staleness.ex | VERIFIED | both exist as cited |

## Standing

- Docs: 12 claims VERIFIED, 4 CORRECTED (all in ocel-egress-forwarder.md),
  3 UNVERIFIABLE (sibling-repo behavior claims, marked in place/by
  evidence note). ex4pm-ontology-pin.md: zero corrections — every claim
  held.
- Real execution evidence: ontology pin byte-identity (claim 19).
- Corrections made to `ocel-egress-forwarder.md` only; no code touched,
  nothing committed.
