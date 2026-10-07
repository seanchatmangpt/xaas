# Stage-4 Entitlement Flow Verification (W402)

Campaign: v26.10.6 CRO-loop, Stage-4 verification. Subject repos:
`/Users/sac/ggen-marketplace` (read-only), `/Users/sac/xaas`. Date: 2026-10-06.

## Pitch claim under test

> "ggmkt v26.10.6 transitions ENTITLEMENT_ACTIVATION_REQUESTED →
> ENTITLEMENT_ACTIVE via Pub/Sub."

## What actually exists (file:line)

- **Commerce sim**: `/Users/sac/ggen-marketplace/k8s/gcp-marketplace-sim/server.py`
  (311 lines) — wire-indistinguishable cloudcommerceprocurement simulator.
  - `:approve` handler (`server.py:168-217`): mints the entitlement record with
    `"state": "ENTITLEMENT_ACTIVE"` directly (`server.py:187`).
  - Pub/Sub **envelope** minted and attached to the approve HTTP response
    (`server.py:201-216`): base64 `ENTITLEMENT_ACTIVE` event inside a wrapped
    push-envelope shape with subscription
    `projects/demo-provider/subscriptions/gcp-marketplace-entitlements`.
  - A pre-seeded `ENTITLEMENT_ACTIVE` demo entitlement binds the aaif-swarm
    mesh's `consumerId` (`server.py:44-62`).
  - Usage admission is entitlement-gated (`server.py:249-303`): `:report`
    returns 403 `ENTITLEMENT_REQUIRED` unless consumerId resolves to an
    `ENTITLEMENT_ACTIVE` record.
- **Typed decide() seam**: `/Users/sac/ggen-marketplace/scripts/entitlement.py` (repo prefix: `ggen-marketplace/scripts/entitlement.py`)
  (359 lines) — `decide()` returns ALIVE (with `backend_standing=SIMULATED`,
  RS256 JWT verified against the x509 metadata endpoint) or BLOCKED with typed
  refusal; loopback fence, real-rail fence (`REFUSED_REAL_NOT_PERMITTED`,
  `server-side` honest BLOCKED for the real cloudcommerceprocurement path,
  `entitlement.py:266-285`).
- **Tests**: `ggen-marketplace/tests/test_entitlement_seam.py` (682 lines),
  `ggen-marketplace/tests/test_commerce_seam_integration.py` (221 lines).
- **Vendored spec**: `k8s/gcp-marketplace-sim/procurement_discovery.json` names
  `ENTITLEMENT_ACTIVATION_REQUESTED` only inside Google's API doc strings
  (enum at line 179; approve-at-REQUESTED semantics at line 709).

## Per-mechanic verdict

| Stage-4 mechanic | Verdict |
|---|---|
| Entitlement activation transition | **EVIDENCED (sim, one-step)** — approve → ENTITLEMENT_ACTIVE (`server.py:168-217`); the ENTITLEMENT_ACTIVATION_REQUESTED state is never held or modeled in code, it exists only in the vendored discovery doc |
| Transition "via Pub/Sub" | **GAP(unevidenced)** — a Pub/Sub-shaped envelope is minted into the HTTP response (`server.py:201-216`); there is no subscriber, no push handler, no REQUESTED→ACTIVE state machine driven by a message |
| Private-offer creation | **EVIDENCED-BY-PROCESS** — CRO-LOOP S4 defines the private offer as human/CRM output with exit gate = offer ID in GCP Marketplace (`/Users/sac/xaas/docs/cro/CRO-LOOP.md` S4); no code path |
| EULA subsumption | **GAP(unevidenced)** — zero hits for EULA across ggen-marketplace `scripts/` and `k8s/` (real grep, exit 1; ggen-marketplace has no `lib/` directory, so the earlier "scripts/k8s/lib" scope was unsound as written) |
| EDP drawdown | **EVIDENCED-BY-PROCESS** — Marketplace-as-channel is the S4 close mechanism; no drawdown code exists |
| License-key / secrets-manager provisioning | **GAP(unevidenced)** — zero hits for secretmanager / license_key across ggen-marketplace `scripts/` and `k8s/` (real grep, exit 1; ggen-marketplace has no `lib/` directory) |

## Stage-3 honest-numbers correction

Pitch-facing claims vs the real corpus on disk:

| Pitch claim | Real corpus (receipted) | Corrected ledger number the pitch should cite |
|---|---|---|
| "eyerun_wasi <15ms" | No `eyerun*` symbol exists anywhere in ggen, ggen-marketplace, or xaas (grep, zero hits). The wasi surface is `packs/wasi-json-abi-pack` (ontology + gates + witnesses); no latency benchmark is receipted. | **Drop the claim entirely** — GAP(unevidenced); nothing to correct it to |
| "44 CASTLE fixtures + 7 auth-floor tests" | CASTLE refusal-negative corpus = 6 batch files, **62 tests** (19+12+7+3+3+18, `w236-refusal-capstone.md` per-file table); auth-floor = **7/7** plug tests (`test/xaas_web/plugs/require_internal_api_token_test.exs`) + 3 body-limit + 4 token-revocation; full negative suite **86 tests / 0 failures** (w236 receipt) | "**62 CASTLE refusal-negative fixtures; 7/7 fail-closed auth-floor plug tests; 86-test negative suite, 0 failures**" |
| Token coverage | 62/62 refusal tokens (w236) | Cite as-is — matches |
| Anti-vacuity | w320: 6 mutants, 4 KILLED / 2 SURVIVED; round-2: gap 1 adjudicated structurally unreachable, no kill test (w378); gap 2 (actuation `external_admission_identity_mismatch`) carries a structural dead-clause witness test (`test/xaas/actuation_refusal_negative_test.exs:194`), not a kill | Cite "6-mutant anti-vacuity audit, 4/6 killed, 2 survivors adjudicated structurally unreachable (w320 + w378)" — **not** "all killed" |
| "w382 round-2 kills" | No w382 artifact exists (`plans/` has w381/w383/w385/w389; w382 appears only as an in-flight lane list entry in `w389-link-check.md:61`) | Cite w320 + w378 by path; do not cite w382 |

## Minimal implementation seam for the GAPs

All Stage-4 code gaps live in ggen-marketplace tooling, not cloud-native
procurement (which stays human/cloud-native by design):

1. **Pub/Sub transition**: a push endpoint in
   `k8s/gcp-marketplace-sim/server.py` (e.g. `POST /pubsub/push`) that accepts
   the `ENTITLEMENT_ACTIVATION_REQUESTED` event, holds the entitlement in a
   REQUESTED map, and only flips to ACTIVE on the approve call — making the
   sim's state machine two-state instead of one-step.
2. **Secrets provisioning**: a `scripts/provision_license.py` in the same
   typed-refusal style as `ggen-marketplace/scripts/entitlement.py` (typed refusals, loopback
   fence) that mints a license key on ACTIVE and writes it to Secret Manager
   (real rail behind a `AAIF_REAL_PERMIT=1` fence, matching the existing
   backend-scoped issuer pattern).
3. EULA subsumption and private-offer creation remain EVIDENCED-BY-PROCESS —
   they are CRM/procurement artifacts, correctly outside the repo.

## Standing

Stage-4 mechanics: **PARTIAL** — the entitlement seam, JWT verification,
entitlement-gated billing, and approve→ACTIVE transition are real, tested code;
the Pub/Sub-driven REQUESTED→ACTIVE machine and secrets provisioning are
unevidenced. Stage-3 numbers: corrected ledger above is receipted at the cited
paths; "eyerun_wasi <15ms" is vapor and must be dropped.
