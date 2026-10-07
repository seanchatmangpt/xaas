# W981r — ash_surface Playwright Re-validation at Post-Regen Subject

Lane: W981r (xaas v26.10.6). Terminal-condition witness for the ash_surface
playwright leg. Prior witness: w901 (371/371 ×2 real Chromium at
`main@d55c576d1`, W937-era). This receipt re-runs the suite for real at the
current xaas subject after the ash_surface regen (xaas `68a5c9f9`, 418
entrypoints, W980k).

## Subjects

| repo | HEAD SHA | commit |
|---|---|---|
| /Users/sac/xaas | `6f235905b6e071c236c5abb0ce0bf872e0bfd7b4` | docs(semantics) dedup W946d |
| xaas ash_surface regen commit | `68a5c9f9c900fb927676c716408929c1a3885962` | chore(ash_surface): regen priv/ash_surface to 418 entrypoints (w978b) |
| /Users/sac/ash_surface | `b70da9e1c2f5c3ff0bc61299b5a0dcc65bcdd1d3` | test: AIRo surface pin court (W675) — 2026-10-07 |

ash_surface working tree is dirty (94 modified/untracked paths, its own
in-flight lanes) — suite ran against the dirty tree at `b70da9e1`, as-is,
read-only. No commits in either repo.

## Command lines

Documented entry: `TESTING.md` "Playwright surface" section → `npm test`
(`node --test test/js/*.test.mjs`), hermetic, loopback-only data: URLs, no
server boot. Runtime gate: `playwright@1.63.0` present in `node_modules`,
Chromium `chromium-1243` + headless shell installed under
`~/Library/Caches/ms-playwright` (fresh boot, no reinstall needed; gate
admitted — see skipped: 0 in the tail).

```
cd ~/ash_surface && npm test
```

Exit: 0. Duration 168.3s.

## Full tail (verbatim)

```
✔ ZOELA MX machine-only closed loop: Observation -> Planning candidate -> Admission -> BRCE DO -> Event projection -> Replay (33.557ms)
ℹ tests 371
ℹ suites 0
ℹ pass 371
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 168322.523375
EXIT:0
```

`skipped: 0` confirms the accessibility suite's Playwright gate was admitted
(real headless Chromium), matching the w901 witness condition (371 pass,
0 skipped).

## Per-failure classification

None — 0 failures on the first run; no rerun needed.

## Standing

**ALIVE** — the ash_surface playwright leg witnesses at the post-regen xaas
subject: 371/371 pass, 0 skipped, 0 failed, real Chromium, exit 0, at
ash_surface `b70da9e1` against the xaas tree containing regen `68a5c9f9`.
No regression from the 182+/10− regen is observable at this surface.

## Falsifier (not run, remains open)

- A failing or skipped test at a future xaas regen subject.
- Note: prior w901 witness ran the suite ×2; this witness ran ×1 per lane
  task. One green run at the new subject is the revalidation evidence
  requested; no failure existed to classify or rerun.
