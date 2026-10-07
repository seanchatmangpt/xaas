# W407 — CRO Stage-3 agent-obliviousness demo (2026-10-06, lane W407)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface` @ `d1db2b03`. Backfill
stub: the artifact landed before its plan receipt; evidence is the artifact
itself.

Artifact: `docs/cro/artifacts/agent-obliviousness-demo.md` (CRO-loop
Stage-3). Evidence: real Phoenix e2e server (BOOT path, port 4097,
`INTERNAL_API_TOKEN=w407-token`, readiness `/internal-api/health` = 200) and
a real Playwright run of `e2e/mcp-a2a.spec.cjs` → **5 passed (22.2s)**;
authenticated `/mcp` surface probes with bearer-token curl transcripts
demonstrating the agent-facing surface carries no internal-state leakage;
read-only lane (no tree changes beyond the artifact).

Falsifier: rerunning the cited Playwright suite at the cited port/token path
yields a non-5-passed result, or the demo's curl transcripts fail to
reproduce against a BOOTed server.
