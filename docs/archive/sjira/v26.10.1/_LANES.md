# Monday demo fan-out — lane map (2026-10-01)

Integration base: `feat/sjira-v26-10-1-chicago-render` @ `56f803c2` (PR #109 head `f343e19a` + origin/main `0a0ecd8b`).
Concurrent external writer: `origin/feat/pradyot-monday-surface-v26.10.1` (3 files under `lib/xaas/demo/pradyot*`, `lib/xaas_web/live/pradyot/`) — lanes are READ-ONLY toward it; coordinator reconciles at integration.

Lane partition = disjoint file ownership. Shared seams (mix.exs, config/*.exs, lib/xaas_web/router.ex, ~/ash_surface/lib) are edited ONLY by the coordinator from lane-submitted lines.

| lane | agent | owns (files) | wave-1 |
|---|---|---|---|
| L1 | sJira contract auditor | `docs/sjira/v26.10.1/**` fixes only | read-only audit |
| L2 | marketplace renderer | `~/ggen-marketplace/packs/chicago-xaas-surface-pack/**` minus `gates/ test/` | read-only plan |
| L3 | marketplace falsifiers | `~/ggen-marketplace/packs/chicago-xaas-surface-pack/gates/**` + `.../test/**` | read-only plan |
| L4 | XaaS consumer | `lib/xaas/chicago/**`, `test/xaas/chicago/consumer/**` | read-only plan |
| L5 | AshSurface //system | `lib/xaas_web/live/system/**`, `test/xaas/chicago/surface/**` | read-only plan |
| L6 | Chicago UI | `lib/xaas_web/live/chicago/**` | read-only plan |
| L7 | ecosystem bridges | `lib/xaas/bridges/**`, `test/xaas/chicago/bridges/**` | read-only plan |
| L8 | negative courts | `test/xaas/chicago/negative_courts/**` | read-only plan |
| L9 | seller projection | `lib/xaas_web/live/chicago/seller*` (owned file prefix) | read-only plan |
| L10 | convergence/red team | nothing (read-only) | audit + risk register |

Contract (verbatim in every dispatch): subject `urn:chicago:agentic-payment:purchase-001`; layer ids `sjira|graphlaw|sa2a|pplan|xaas|ex4pm|beam4pm|affidavit|ashsurface|marketplace`; standing `UNKNOWN|PARTIAL_ALIVE|ALIVE|BLOCKED|BUILD_BROKEN|UNSUPPORTED|REFUSED_*`; generated artifacts `priv/chicago/chicago.{machine,verification,executive,replay}.json` with `generated=true`, `authorityClaim=NONE`, subject + source-digest + generator-identity fields; authority ceiling of all surfaces = NONE; no owned-collaborator mocks; real Postgres/Ecto sandbox/Ash/HTTP; no git by lanes; coordinator owns git, seams, integration, PR.

Wave plan: wave 1 = 10 read-only lanes (plans ARE the collision analysis) → coordinator resolves seams → wave 2 = write lanes → audits + red team → verify ladder → per-repo commits/PRs → MONDAY_DEMO_RECEIPT.
