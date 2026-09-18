# SA2A Release v26.9.17 — Orient (t1: pin-exact-heads)

Date: 2026-09-17. Source domain: operator HDDL `sa2a-v26-9-17-domain.hddl`
(paste archive: /Users/sac/.zcode/tmp/paste-attachments/2026-09-17/pasted-text-20260917-000929-66de71ad.txt).

Top task `qualify-v26-9-17`: Orient → CloseBoundaries → Episode₁(discovery) → Episode₂(replay) → Certify.
This wave executes t2 only; t3–t5 gated on t2 closure (ordered-subtasks).

## Pinned heads (boundary → repo → branch → HEAD → dirty-files)

| # | repo | capability | branch | HEAD | dirty |
|---|------|-----------|--------|------|-------|
| r1 | /Users/sac/ash_a2a | cap-orchestration | main | 02d8616 | 0 (worktrees exist — do not touch) |
| r2 | /Users/sac/ash_r2rml | cap-semantic-feedback | epoch/v26.9.15-semantic-subject | 7d958a8 | 0 |
| r3 | /Users/sac/bcinr | cap-bounded-select | release/26.9.15 | f70999c0 | 0 |
| r4 | /Users/sac/ggen | cap-manufacture | feat/marketplace-sparql-semantic-search | 03ceb0df6 | 0 |
| r5 | /Users/sac/ggen_igniter | cap-framework-projection | feat/calver-ticket-day-pack | d018ed4 | 0 |
| r6 | /Users/sac/xaas | cap-system-authority | feat/execution-actuation-fabric | fd68647 | 15 (grew from 9 on 2026-09-16) |
| r7 | /Users/sac/affidavit | cap-standing | main | 7f1caf6 | 2 |
| r8 | /Users/sac/beam4pm | cap-process-court | main | ace23e5 | 17 |
| r9 | /Users/sac/autofde-lab | cap-crown | master | 00af45ee | 10 |

Non-critical (owned, not in this wave): unrdf (cap-runtime, wip branch, 32 dirty), wasm4pm (cap-portable-runtime).

## Wave assignment (10 orthogonal agents)

- Agents 1–9: one per critical boundary, `verify-boundary → resolve-boundary-result` per FOND topology.
- Agent 10: zcode↔xaas executor connection, DESIGN.md phases P0+P1 (/tmp/uzc/DESIGN.md), confined to ~/xaas plugin/template scope (mkdir-serialized with agent 6 via /tmp/uzc/xaas-mix.lock) + ~/.zcode installed-plugin sync.
- Receipts: /tmp/uzc/boundary-<name>.md and /tmp/uzc/zcode-connection-P0P1.md.

## FOND outcome vocabulary (binding)

`qualified | build-broken | blocked | unsupported` per boundary; recovery = repair-build (narrow) or reroute-blocked (topology); UNSUPPORTED has NO generic repair method — typed stop.
