# W784 — TOFU / defer-to-parent probe (v26.10.6)

**Standing: UNSUPPORTED** — deferred-to-parent (TOFU) agent-card verification is
**unimplemented in xaas** at HEAD `a0723bf6` (branch `feat/playwright-surface`).
No test file was written; option (b) applies. Evidence, not invention.

## Grep matrix (all run at HEAD a0723bf6, 2026-10-07)

| # | Pattern | Scope | Hits |
|---|---------|-------|------|
| 1 | `tofu\|trust-on-first\|defer.to.parent\|defer_to_parent\|parent.?card\|parent_card` | `lib/`, `test/` (`*.ex`, `*.exs`) | **0** |
| 2 | same patterns | `deps/ash_a2a/lib` (pinned dep), `docs/claude` | **0** |
| 3 | `defer` in `lib/xaas/a2a/` | a2a context | **0** |
| 4 | `pin\|rotat\|jwks\|signature\|verif` in `lib/xaas/a2a/`, `lib/xaas_web/a2a/` | closest-neighbor scan | matches only for unrelated concepts: card cache pinning (`lib/xaas_web/a2a/v1_transport_plug.ex:6,23`), dep-pin survey notes (`lib/xaas_web/a2a/next_read_ash_agent.ex`), forward-only transition allow-list (`lib/xaas/a2a/validations/forward_only_transition.ex:5`), Phoenix-token verification note (`lib/xaas_web/a2a/next_read_ash_agent.ex:50`) |

## What the real A2A surface actually is

- `lib/xaas/a2a/agent.ex` — one v1 agent card as an Ash resource.
- `lib/xaas/a2a/catalog.ex` — card **ingest** with typed ingest errors
  (`agent-card ingest refused (...)`), the nearest real seam to card verification,
  but it is single-card ingest with no first-use pinning, no subsequent-rotation
  refusal, and no parent-delegation chain.
- `lib/xaas_web/a2a/v1_transport_plug.ex` — serving/caching contract only.

## Verdict

TOFU pinning / subsequent-rotation refusal / defer-to-parent chain semantics do not
exist as executable code in this repo or in the pinned `ash_a2a` dep. Naming the
concept in dissertation/docs is not capability. Any "TOFU chain" claim is
`UNSUPPORTED (no toful surface)`; the concept is filed here as a typed gap for the
campaign backlog, not manufactured in this lane.

## Receipt fields

- **Subject**: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface, lane W784
- **O/O***: grep matrices above (real command output, empty result sets are the evidence)
- **Transport failures**: none
- **μ/diff**: none — write-only receipt (this file). No lib/ or test/ change.
- **Commands**: `grep -rniE 'tofu\|trust.on.first\|defer...' lib/ test/` → 0 hits;
  `grep -rniE ... deps/ash_a2a/lib docs/claude` → 0 hits
- **Verification ladder**: static grep only (appropriate: the claim is one of absence;
  the absence-claim's falsifier is the grep matrix itself, re-runnable)
- **Replay**: `grep -rniE 'tofu\|trust.on.first\|defer.to.parent' lib/ test/ deps/ash_a2a/lib` → expect empty
- **Standing**: UNSUPPORTED — typed gap, deferred to campaign backlog
