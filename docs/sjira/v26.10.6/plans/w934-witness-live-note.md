# W934 — WitnessLive Mount-Only Read Note (receipt)

- **Subject**: /Users/sac/xaas @ a0723bf6, branch `feat/playwright-surface`. Author of record: `/Users/sac/xaas/docs/cro/artifacts/witness-live-court-note.md` (new; the only file written besides this receipt).
- **O***: W888's receipt (docs/sjira/v26.10.6/plans/w888-witness-live-court.md) documented that WitnessLive reads once in mount/3 with no PubSub/handle_info — re-mount is the real update mechanism. Worth capturing as a design fact. Read the W888 receipt and `lib/xaas_web/live/witness_live.ex` in full.
- **μ/diff**: +1 doc artifact (≤10 lines): mount-only read contract, re-mount update mechanism, W888 court evidence (4/4, exit=0), and a DESIGN-class follow-up option (PubSub subscription, v26.10.7+, to be specified in W905's spec format). No code, no `lib/` edits, no build root.
- **Commands/exits**: none required (documentation-only lane; facts sourced verbatim from the W888 receipt and the LiveView source, both read this lane).
- **Verification ladder**: source-inspection only, per lane scope; the underlying facts carry W888's observed-execution standing (ALIVE on a0723bf6).
- **Standing**: ALIVE for the note itself (artifact written, facts traceable to the W888 receipt + source); the documented WitnessLive behavior stands ALIVE via W888's receipt, not re-proven here.
- **Typed gaps**: full `mix test` not run (doc-only lane; nothing compiled or executed). PubSub enhancement is UNKNOWN/DESIGN-class until specified and falsified per W905's format.
- **Cleanup**: no build root created; nothing to clean.
