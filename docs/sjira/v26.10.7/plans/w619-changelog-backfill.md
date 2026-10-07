# W619 — Changelog + diataxis backfill (WP-5, v26.10.7)

Date: 2026-10-07. Lane W619. Repo: /Users/sac/xaas, branch
`feat/playwright-surface`. No commits made, no mix commands, per dispatch.

## Pages touched

- `CHANGELOG.md` — new "## [In progress] — v26.10.7" section inserted
  before the v26.10.6 section: graphql removal (w984ao, ALIVE),
  OS-16 PROV-O headers (IN FLIGHT), PEP seam spec (w613),
  fuzz harness + gate log (w614), OS-20 per-repo sweep verdicts
  (w608 no-manifestation vs w609 deviation-confirmed, disclosed
  not reconciled), fleet version bump (w618), w601p seal,
  w601q v26.10.6 tag, OS-13 markers verified (w610), and an
  explicit "no receipt on disk yet" list for OS-18/w601, OS-14/w603,
  OS-15/w604, OS-19/w612, w615, w616, w606, w607.
- `docs/claude/diataxis/reference/http-api-surface.md` — added a
  "Provenance pipeline" bullet to Router topology: `pipeline :prov_origin`
  + plug on `/a2a` and `/api` only, standing UNKNOWN, cited to w605.
  Verified on disk before writing: `lib/xaas_web/plugs/prov_origin_header.ex`,
  `test/xaas_web/prov_origin_header_test.exs`, router wiring at
  `lib/xaas_web/router.ex:29,211-213,322`.
- `docs/claude/diataxis/reference/eu-ai-act-semantics.md` — two new
  sections before See Also: "Transport provenance headers (OS-16,
  IN FLIGHT — w605)" and "PEP seam: agentgateway filter spec +
  prompt-injection harness (WP-3, IN FLIGHT)" (w613 spec-only
  disclosure + w614 gate-log numbers, daemon-absent cases NOT RUN).
- `docs/sjira/v26.10.7/plans/w619-changelog-backfill.md` — this receipt.

## Receipts read before citing

- `docs/sjira/v26.10.6/plans/w984ao-graphql-removal.md` (ALIVE)
- `docs/sjira/v26.10.7/plans/w601p-phase0-seal.md` (ash_pplan ALIVE
  ff to 6dbd3b0; wasm4pm BLOCKED main-diverged)
- `docs/sjira/v26.10.7/plans/w601q-tag-prep.md` (tag v26.10.6 on
  cf228da6, not pushed; release/v26.10.7 cut)
- `docs/sjira/v26.10.7/plans/w605-prov-o-plug.md` (UNKNOWN)
- `docs/sjira/v26.10.7/plans/w608-a2a-map-update.md` (no manifestation)
- `docs/sjira/v26.10.7/plans/w609-pplan-map-update.md` (deviation
  confirmed; court 12 passed)
- `docs/sjira/v26.10.7/plans/w610-fixtureonly-markers.md`
  (PARTIAL_ALIVE, zero edits)
- `docs/sjira/v26.10.7/plans/w613-pep-filter-spec.md` (PARTIAL_ALIVE,
  spec-only)
- `docs/sjira/v26.10.7/plans/w614-goose-harness.md` +
  `w614-gate-log.json` (10/10 all_ok)
- `docs/sjira/v26.10.7/plans/w618-fleet-version-bump.md`
  (PARTIAL_ALIVE, uncommitted)

## Honest disclosures

- No receipts exist on disk for w601 (OS-18), w603 (OS-14), w604 (OS-15),
  w606, w607, w612 (OS-19), w615, w616 at record time. They appear in
  CHANGELOG only as dispatched IN-FLIGHT lanes with no factual claims;
  diataxis was not extended for them.
- w608 vs w609 disagree on whether the OS-20 Map.update deviation
  manifests (ash_a2a: standard semantics; ash_pplan: deviation live)
  while both name the same toolchain (OTP 29.1.1 / Elixir 1.20.4).
  Recorded per-repo as written, disagreement disclosed in CHANGELOG;
  reconciliation is not this lane's scope.
- GraphQL removal was already documented in
  `ash-is-the-xaas.md` + `ash-configuration.md` by a sibling lane;
  this lane did not duplicate it there.
- Line-length gate: `awk 'length>100'` over all three edited files —
  every flagged line pre-existing; all inserted lines ≤100 chars.

## Standing

- Landed (receipt-backed, ALIVE/PARTIAL_ALIVE as cited per item):
  CHANGELOG + 2 diataxis pages, grounded only in read receipts.
- Doc standing = the weakest cited receipt per item; IN-FLIGHT items
  carry no standing claim. W619 lane standing: PARTIAL_ALIVE (docs
  written to disk, uncommitted; coordinator owns integration).
