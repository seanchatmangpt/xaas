# W383 — Doc Map Sweep Receipt (P2-6)

Lane: W383, repo /Users/sac/xaas @ feat/playwright-surface, 2026-10-06.
Read-only sweep; this file is the only write (per contract).

## 1. Link existence (27 links in docs/claude/diataxis/README.md)

All 27 linked paths tested with `test -f`: 27/27 OK, 0 missing. Includes the
relative case-study link `../../case-studies/next-read/README.md` (resolves to
`/Users/sac/xaas/docs/case-studies/next-read/README.md`).

## 2. Family claims vs reality

Map lists Tutorials=2, How-to=4, Reference (core)=4, Reference (previously
unindexed)=2, Explanation (core)=3, Explanation (evidence)=11, Case Studies=1.
Disk counts match exactly:
- tutorials/: 2 files
- how-to/: 4 files
- reference/: 7 files on disk (6 indexed; `generated-castle-bridge-errc.md`
  exists on disk but is NOT indexed in the map)
- explanation/: 14 files on disk (14 indexed)

## 3. Current-surface checks

- `/a2a/v1` naming: reference/http-api-surface.md names
  `XaasWeb.A2A.V1TransportPlug` (wrapping `AshA2A.Protocol.Plug`) at lines 41
  and 618 — CURRENT. `lib/xaas_web/a2a/v1_transport_plug.ex` exists.
- `/witness` route: `lib/xaas_web/router.ex:62` has
  `live("/witness", WitnessLive)` — CURRENT.
- W328/W376-corrected pages: no W328/W376 references in diataxis/ (map points
  to no page by those IDs); no dangling reference — vacuously CURRENT.

## 4. Root README.md doc pointers

- `docs/claude/diataxis/README.md` link (line 9): OK.
- `docs/ultracode/eight-hour-run.md` (line 16): OK.
- `docs/archive/` (line 16): OK (docs/archive/README.md exists).

## Claim table

| # | Claim | Verdict |
|---|-------|---------|
| 1 | 27 map links resolve | CURRENT |
| 2 | Family counts match disk | CURRENT |
| 3 | V1TransportPlug naming | CURRENT |
| 4 | /witness surface | CURRENT |
| 5 | W328/W376 pointers | CURRENT (no such pointers exist) |
| 6 | Root README doc pointers | CURRENT (3/3 resolve) |

## Corrections for coordinator

1. (minor, non-broken) `reference/generated-castle-bridge-errc.md` exists on
   disk but is not listed in the diataxis README map. Optional correction: add
   it under the "Reference pages not previously indexed" list (README.md:57).
   Not a STALE claim — the map makes no false statement about it.
