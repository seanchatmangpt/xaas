# W402 — CRO Stage-4 entitlement-flow verification (2026-10-06, lane W402)

Subject: `/Users/sac/ggen-marketplace` (read-only) + `/Users/sac/xaas` @
`feat/playwright-surface` @ `d1db2b03`. Backfill stub: the artifact landed
before its plan receipt; evidence is the artifact itself.

Artifact: `docs/cro/artifacts/stage4-entitlement-flow-verification.md`
(CRO-loop Stage-4). Evidence: the ggen-marketplace entitlement seam verified
against real code — commerce simulator approve→`ENTITLEMENT_ACTIVE`
(`k8s/gcp-marketplace-sim/server.py:168-217`), Pub/Sub-shaped envelope minted
into the HTTP response with no subscriber/state machine (GAP),
entitlement-gated usage admission 403 `ENTITLEMENT_REQUIRED`
(`server.py:249-303`), typed `decide()` seam with real-rail fence
`REFUSED_REAL_NOT_PERMITTED` (`scripts/entitlement.py:266-285`); Stage-3
honest-numbers correction table grounding "62 CASTLE fixtures / 86-test
capstone" at w236 and dropping "eyerun_wasi <15ms" as vapor.

Falsifier: any file:line verdict in the artifact not reproducible by reading
the cited ggen-marketplace file at the current head.
