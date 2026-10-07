# W322 — Zero-Config Refusal/Safety Posture Audit (EU AI Act mandate, vector c)

Claim under test: the refusal/safety posture requires ZERO operator configuration;
configurable safety = liability transfer = anti-selling, so any config-gated safety
law is a finding.

Subject: /Users/sac/xaas @ feat/playwright-surface (canonical checkout, read-only sweep)
+ /Users/sac/ash_surface (read-only). Method: real grep + read, every site cited
file:line. No fixes applied, per lane contract.

## Verdict

**zero-config posture: HELD**

Category (c) findings (SAFETY-ADJUSTABLE knobs that weaken/disable a refusal): **zero**.

## Method

- Full grep of `lib/` for `Application.get_env/fetch_env/put_env` and `System.get_env`
  (all output captured in session; every hit classified below).
- Refusal-site sweep: `grep REFUSED|BLOCKED` over `lib/` and `lib/xaas_web/{a2a,plugs}/`.
- Anti-pattern checks: env/app-env that disables RequireInternalApiToken, toggles castle
  verification off, widens the body limit from config, or disables actuation admission.
- ash_surface: full grep of its `lib/` — **zero** `System.get_env` /
  `Application.get_env` / `Application.fetch_env` hits in the entire lib tree. Its
  REFUSED surfaces (standing.ex, vocabulary.ex, intent/dispatch.ex, ir/event_projection.ex,
  command_center.ex, planning_episode.ex, health.ex, telemetry.ex, ash_surface.ex,
  projectors/js.ex, projector/expo.ex) therefore read no config at all on any refusal
  path.

## Inventory: config reads on or adjacent to safety paths

| Site | What it reads | Category |
|---|---|---|
| lib/xaas_web/plugs/require_internal_api_token.ex:95,103 | `System.get_env("INTERNAL_API_TOKEN")` — presence-only, fail-closed 503 when unset (line 96, 146-154); no skip/disable key exists anywhere in the plug | (a) authority/admission context |
| lib/xaas/actuation.ex:554-560 (`admit_authority/2`) | No config read. `authorize?: false` demands non-empty `authority` map else `:delegated_actuation_requires_authority_evidence` | (a) |
| lib/xaas/actuation.ex:162-178 | `idempotency_key` from caller opts only; missing → `:idempotency_key_required` | (a) |
| lib/xaas/castle.ex:59,528 | `Application.get_env(:xaas, :castle_kernel_module, CLI)` — swaps the DO executor module behind already-admitted DO; admission gates (`Xaas.Castle.Admission.witness/checkpoint`, castle.ex:526-527) run BEFORE the kernel regardless; refusals `REFUSED_XAAS_*` unaffected. No config file sets it (grep of config/ = no hits) | (b) environment pin / test seam |
| lib/xaas/castle.ex:787 (`build_request`) | `:castle_adapter_profiles` — server-owned allowlist (`allowed_authorities`, castle.ex:805-808); missing profile → `REFUSED_UNKNOWN_CASTLE_ADAPTER_PROFILE` (fail-closed, default `%{}`); authority not in list → `REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED` | (a) authority allowlist |
| lib/xaas_web/endpoint.ex:81 | Plug.Parsers `length: 8_000_000` — **hardcoded literal**, not read from config | n/a (static law) |
| lib/xaas_web/plugs/a2a_parse_floor.ex:24,45 | `@max_body 8_000_000` module attribute — hardcoded; `{:more, ...}` → parse error, fail-closed | n/a (static law) |
| lib/xaas_web/a2a/next_read_ash_agent.ex:37 | `A2A_BASE_URL` env — client endpoint pin, no refusal path reads it | (b) |
| lib/xaas_web/plugs/ontop_proxy_plug.ex:102,105 | http client module + base URL — transport pins | (b) |
| lib/xaas/secrets.ex:5 | `:token_signing_secret` fetch — key material | (a) |
| Castle CLI kernel env pins (castle.ex:552-566 moduledoc) | `CASTLE_BIN`, `CASTLE_BIN_SHA256`, `CASTLE_SIGNING_KEY_PATH`, `CASTLE_KEY_ID`, `CASTLE_EVIDENCE_ROOT` — required; absence fails the runtime, never weakens a refusal | (b) |

All other Application.get_env hits in lib/ (ultracode_*, library_*, ontop_*,
marketplace_catalog_source, chicago loaders, health overrides, cnv_deploy_base_url,
capability_pack_pins, sa2a/execution_policy.ex:48, ils_repo/sip2_adapter.ex:53) sit on
non-refusal paths: loaders, seams, dirs, budgets, topic names. None gate a REFUSED/
BLOCKED site. `Xaas.Sa2a.ExecutionPolicy.config/0` (execution_policy.ex:48) normalizes
pipeline policy config, not an admission/refusal toggle.

## Anti-pattern checks (all negative)

1. **Disable RequireInternalApiToken**: no such key. Plug reads only
   `INTERNAL_API_TOKEN` (require_internal_api_token.ex:95,103); unset env ⇒ 503
   fail-closed (lines 96-98, 146-154). The DB-token tier is additive auth, not an
   opt-out.
2. **Toggle castle verification off**: no boolean/enable key exists. Verification
   (`verify_outer_intent` castle.ex:360, `verify_outer_receipt` :390,
   `verify_checkpoint_receipt` :415, `verify_checkpoint` :431,
   `verify_runtime_checkpoint` :868, `verify_evidence` :695) is unconditional in the
   with-chains; the only config keys (`:castle_kernel_module`, `:castle_adapter_profiles`)
   cannot bypass it — an unknown/absent profile or authority REFUSES.
3. **Body limit from config**: `length: 8_000_000` is a literal at endpoint.ex:81;
   a2a_parse_floor.ex mirrors it as a module attribute (:24). No config read.
4. **Actuation admission off-switch**: none. `Xaas.Actuation.Kernel.do_admit`
   (actuation.ex:330-340) always runs `admit_authority` + `Registry.admit`
   (ontology projection admission); `authorize?: false` actually *tightens* the gate
   (actuation.ex:554-558 requires authority evidence).

## Category (c) findings

None. Quoted-code requirement not triggered (expected-zero confirmed).

## Standing

Observed (grep+read on the exact working tree). Not court-executed; the falsifier
for this receipt would be a mutation court that injects a
`config :xaas, :safety_off, true`-style key and asserts no behavior change —
structure above already shows no read site exists to consume it.
