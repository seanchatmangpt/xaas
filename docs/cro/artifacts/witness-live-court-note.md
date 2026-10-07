# WitnessLive — Mount-Only Read Contract (design note)

Source: `lib/xaas_web/live/witness_live.ex` @ a0723bf6; court evidence: W888 receipt
(`docs/sjira/v26.10.6/plans/w888-witness-live-court.md`, 4/4 passed, exit=0).

- **Contract**: WitnessLive reads once in `mount/3` (`list_receipts/0`: `Ash.Query.sort(inserted_at: :desc)` + `Ash.read!/1`). No PubSub subscription, no `handle_info`/`handle_event` clauses — the surface is render-only after mount.
- **Update mechanism**: re-mount. A fresh LiveView mount is the real (and only) refresh path; mid-session ingests appear only on a new mount. Asserted directly by W888 court test (b): a second `Catalog.ingest/1` is visible on re-mount, both subjects present, newest-first.
- **Standing**: ALIVE on exact subject a0723bf6 (observed execution, W888).
- **Court evidence (W944b fold, 2026-10-07)**: route-collision court for `AuditExportToken` :use/:revoke (`test/xaas_web/audit_export_token_route_collision_court_test.exs`) — 4 passed, RESOLVED-AT-HEAD at `fab56ae1`, distinct routes verified at 3 layers (resource table, runtime match table, real HTTP probes → 200 with persisted asserts); F2 controller repoint landed as W959, 10/10 (`docs/sjira/v26.10.6/plans/w944b-route-collision.md`, `plans/w959-controller-repoint.md`).
- **Follow-up (v26.10.7+)**: a PubSub subscription + `handle_info` re-read would make the surface live-update mid-session. Typed DESIGN-class; to be specified in W905's spec format before any admission. Not a defect — current behavior is the documented, court-tested contract.
