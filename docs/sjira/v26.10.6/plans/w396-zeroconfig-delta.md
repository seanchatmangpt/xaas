# W396 — Zero-Config Posture Delta Re-Audit (post-W322 env-reading changes)

Lane: W396. Repo: /Users/sac/xaas @ feat/playwright-surface (canonical checkout,
read-only sweep; only this receipt written). Subject: env-reading changes in `lib/`
that landed after W322's audit
(`docs/sjira/v26.10.6/plans/w322-zero-config-posture.md`, verdict HELD, zero
category-(c) findings).

Method: `git diff main...HEAD -- lib/ lib/xaas_web/ | grep '^+.*get_env'` plus
`git diff -- lib/ lib/xaas_web/` (uncommitted) with the same filter, cross-checked
against a direct grep of the live tree; each new site read in context and
classified. No mocks, real grep+read on the exact working tree.

## Baseline: W322 inventory (recorded sites, unchanged)

- `INTERNAL_API_TOKEN` (require_internal_api_token.ex:95,103) — fail-closed 503
  when unset; no skip key. (a)
- `castle_kernel_module`, `castle_adapter_profiles` (castle.ex:59,528,787) — (b)/(a);
  admission runs before kernel, unknown profile REFUSES.
- `A2A_BASE_URL` (next_read_ash_agent.ex:37) — transport pin (b).
- ontop_proxy_plug transport pins, secrets.ex `:token_signing_secret` (a),
  castle CLI env pins (b), body limits hardcoded literals.
- Everything else on non-refusal paths.

## Delta table: env reads added since W322's subject tree

| # | Site (file:line) | What it reads | Classification | Rationale |
|---|---|---|---|---|
| 1 | lib/xaas/vault.ex:30 (with :23) | `CLOAK_KEY` (second bare read) | **fail-CLOSED-safety (strengthens)** | OS-17 guard (w349 found the gap, w393 traced it, this guard is the fix): `Mix.env() == :prod and CLOAK_KEY in [nil, ""]` → `{:stop, {:cloak_key_missing, :prod_refuses_placeholder_key}}` — the :permanent child crash-loops the node rather than booting prod on the committed public placeholder key. This is the opposite of a category-(c) knob: the env read *adds* a refusal. Note: line 23's fallback-read remains fail-open outside prod, exactly as W322's posture intends (dev convenience, disclosed placeholder). |
| 2 | lib/xaas/bridges/pplan.ex:211 (`store!/0`) | `Application.get_env(:xaas, :pplan_durable_store)` | **fail-CLOSED-safety (strengthens)** | Absent → `raise` with a typed instruction. No default store is silently substituted; missing config cannot let a "durable" purchase run proceed non-durably. Was in the committed-diff adds (bridges/pplan.ex is new this campaign). |
| 3 | lib/xaas_web/controllers/health_controller.ex:161 (`ontop_configured?/0`) | `:ontop_endpoint` | non-safety | Opt-in sub-check of the health aggregate: absent → `{:skipped, :not_configured}`, a disclosed skip, not a passed check; configured-but-unreachable still fails the aggregate. Follows W174's law "unconfigured != down". Weakest of the set but gates only whether an extra probe runs, never whether a refusal fires. |
| 4 | lib/xaas_web/controllers/health_controller.ex:249 | `:health_node_boot_at_override` | non-safety | Test-only seam for warmup-window typing (W310h); documented in-line as such; no refusal path consumes it. |
| 5 | lib/xaas_web/router.ex:204,217,222 | `A2A_BASE_URL` (3 new mounts: zoe-event, v1, base) | (b) transport pin | Same variable, same role as the already-inventoried next_read_ash_agent.ex:37 read; endpoint pin with localhost fallback, no refusal path reads it. |
| 6 | lib/mix/tasks/xaas.episode.ex:150, xaas.machine_experience.ex:91, xaas.replay.ex:67, lib/xaas/sjira/successor.ex:67,78, lib/xaas/ultracode/semantic_replay.ex:123 | `System.get_env()` passed INTO `SemanticDrive.no_llm_guard/1` | (a) fail-closed-safety, pre-existing | Verified pre-campaign (not in the main...HEAD added lines). Included because the task asked for a refusal-adjacent sweep: these env reads *feed a guard* — the guard REFUSES (`{:refused, typed}`) when LLM-era env is present. Env here triggers refusal, never disables it. Not a new hit, not category (c). |
| 7 | lib/mix/tasks/xaas.ash_surface.ex (put_env of `@manifest_env_key`) + marketplace_catalog_source get_env | `Application.put_env` writes / catalog source | (b) | Data wiring (manifest key, catalog path), no refusal gating. |

## Repo-wide category-(c) sweep (env read that disables a refusal)

Grep of all `get_env` sites within ±2 lines of refusal vocabulary across `lib/`:
every env-adjacent refusal is (i) the OS-17 guard (refuses on env ABSENCE in prod),
(ii) `no_llm_guard` (refuses on env PRESENCE of LLM knobs), or (iii) fail-closed
raises (`store!/0`). **Zero sites where an env/config read turns a refusal off.**
w394's policy did not land in lib/ (no such file in the diff); w349 landed
test-only (`test/xaas/vault_env_guard_test.exs`) plus the (later) OS-17 lib guard
in vault.ex, both inventoried above.

## Verdict

**STILL-HELD** — all new env reads since W322 are fail-closed-safety (OS-17
CLOAK_KEY prod refusal; pplan `store!/0` raise), fail-closed (b) pins
(A2A_BASE_URL, put_env wiring), or non-safety (health sub-check skip, test-only
seam). Zero new category-(c) hits (config that disables a refusal).

## Standing

Observed (grep+read on the exact working tree at feat/playwright-surface).
Not court-executed; falsifier: a mutation court injecting
`config :xaas, :safety_off, true` / env `XAAS_DISABLE_REFUSALS=1` and asserting
no behavior change — this delta audit shows no read site exists to consume either.
