# sJira v26.9.21 — XaaS ZOE event simulation WIP

Canonical source: work-orders.ttl. This Markdown file is a non-canonical projection for review.

Source review subject: seanchatmangpt/xaas PR #58 at fee6edd2333b6e0ed23327d34f61c6b13ac5591d.
Tracking branch base: main at 8e72cfcb85bd901ad067589295598eb7580a1442.
Evidence ceiling: SIMULATION_ONLY.
Authority ceiling: OBSERVE / SELECT / CONSTRUCT. Production DO is excluded.

| Work order | Standing | Remaining consequence |
| --- | --- | --- |
| XAAS-SJIRA-2621-001 | PARTIAL_ALIVE | Replace blacklist-only participant admission on the direct A2A simulation path with the strict zoe-event-ops/v1 participant allowlist. |
| XAAS-SJIRA-2621-002 | BLOCKED | After 001, execute and receipt the exact-head focused simulation + real A2A court. |
| XAAS-SJIRA-2621-003 | BUILD_BROKEN | Separately repair the existing ex4pm / Igniter.Mix.Task production compile failure; it is not evidence against the simulation semantics. |

The graph does not admit live Planning Center reads, Planning Center writes, CommandBus execution, deployment, publication, merge, or runtime ALIVE standing.

Projection manufacture: handwritten because no admitted sJira projection generator is present in this repository; canonical semantics remain in work-orders.ttl.
