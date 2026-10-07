# Lane X4 — v26.10.5 Version-Alignment Audit (READ-ONLY evidence)

Date: 2026-10-06. Scope: the 13 fleet repos. Target: v26.10.5.
All findings cite real file:line reads taken this session (no memory, no inference).

## 1. Self-version inventory (current → target 26.10.5)

| Repo | File:line | Current | Target | Action |
|---|---|---|---|---|
| ggen | `Cargo.toml:2` | 26.10.5 | 26.10.5 | aligned |
| ggen-marketplace | `Cargo.toml:2` | 26.10.5 | 26.10.5 | aligned (latest git tag only v26.10.2 — tag lag, not a pin conflict) |
| ferroplan | `Cargo.toml:2` | 26.10.5 | 26.10.5 | aligned |
| gymact | `Cargo.toml:2` | 26.10.5 | 26.10.5 | aligned (beam/ subapp `beam/mix.exs:7` still 26.8.8 — legacy, flag only) |
| ggen_igniter | `mix.exs:9` | 26.10.5 | 26.10.5 | aligned (`source_ref: "v26.10.5"` at mix.exs:78) |
| ash_a2a | `mix.exs:29` | 26.10.5 | 26.10.5 | aligned (latest tag v26.10.3 — tag lag) |
| ash_pplan | `mix.exs:4` | 26.10.3 | 26.10.5 | SEAM 1 |
| ash_surface | `mix.exs:4` | 26.10.1 | 26.10.5 | SEAM 2 |
| beam4pm | `mix.exs:11` | 26.10.1 | optional | SEAM 9 |
| xaas | `VERSION` (read at `mix.exs:13`) | 26.10.2 | 26.10.5 | SEAM 3 |
| wasm4pm | `package.json:3` | 26.9.28 | 26.10.5 | SEAM 4 |
| zcode-cli | `package.json:3` | 3.14.3-1 | n/a | out-of-scheme (independent versioning), no alignment |
| autofde-lab | `package.json:3` | 0.1.0 | n/a | out-of-scheme, no alignment |

Adjacent siblings (outside the 13-repo list, consumed as deps — flagged, not seamed here):
ash_graphlaw `mix.exs:11` = 26.10.1, ash_affidavit `mix.exs:9` = 26.10.1,
ash_r2rml `mix.exs:9` = 26.9.28, ex4pm `mix.exs:18` = 26.10.2, ash_ex4pm `mix.exs:4` = 26.10.4.

## 2. Cross-repo dependency pins (the C03 skew surface)

### xaas → family (/Users/sac/xaas/mix.exs)
- `:ash_a2a` git ref `3325032d9dea201e6deb82ef242c534aacb3b420` (mix.exs:104-105; mix.lock:7).
  Local ash_a2a HEAD = `07180bd3be686db25b61918770a76a003349ba29` (self-version 26.10.5). SKEW.
- `:ash_pplan` git ref `b9da1ad7590d70afac5eace3bd7ba1a644f7249f` (mix.exs:252-253; mix.lock:25).
  Local ash_pplan HEAD = `414a393d17afa6637ce1db5c34fab09e032c58c8` (self-version 26.10.3). SKEW.
- `:ggen_igniter` hex `~> 26.10.1` (mix.exs:226; mix.lock:86 locks hex 26.10.1).
  ggen_igniter 26.10.5 exists locally; hex 26.10.5 must be published before this range resolves. SEAM 5.
- `:ash_surface` path dep `../ash_surface` (mix.exs:115) — inherits SEAM 2 automatically.
- `:ash_r2rml` git ref `36f25a30f2f60acde7da1a965626451dbc40b6f8` (mix.exs:108-109).
  Local HEAD = `0d5320f6c5e9a43bb3e8dcb0f30d301b1ebb64d7`. SKEW.
- `:ex4pm` git ref `17e7761ffff482ff1b2ec936ad9705a99356451a` (mix.exs:245-246; mix.lock:68).
  Local HEAD = `9f7aecda87e5110f668f824bbae760f6c97f88e1` (26.10.2). SKEW.

### ash_surface (/Users/sac/ash_surface/mix.exs)
- `:ash_r2rml` `~> 26.9` (line 132), `:ash_a2a` `~> 26.9` (line 133), both `runtime: false`.
  `~> 26.9` admits 26.10.x, so no hard skew; optional consistency tightening. SEAM 10.

### ash_a2a (/Users/sac/ash_a2a/mix.exs) — self 26.10.5, no seams needed
- `:ggen_igniter` `~> 26.9` dev (339), `:ash_graphlaw` `~> 26.10` (340), `:ash_affidavit`
  `~> 26.10` (341), `:ash_ex4pm` `~> 26.10` (342), `:ash_pplan` `~> 26.10` test (358),
  `:ash_r2rml` `~> 26.8` (369) — all satisfied by current versions.

### beam4pm (/Users/sac/beam4pm/mix.exs)
- self `version: "26.10.1"` (line 11).
- `:ash_a2a`: hex `~> 26.9.30` when `hex_publish?` (line 128), else git ref
  `80b77e225814d7a10a724e5ac01318600c71ee4c` (lines 130-132). SKEW vs local HEAD `07180bd3…`.
- `:ggen_igniter` `~> 26.9` (line 76) — satisfied.

### ggen_igniter (/Users/sac/ggen_igniter/mix.exs) — self 26.10.5, no seams
- `:ash_a2a` `~> 26.9` dev/test (line 271) — satisfied by 26.10.5.

### ggen-ecosystem (outside 13-repo scope, noted)
`/Users/sac/ggen-ecosystem/ecosystem.lock.toml`: `[ggen] release = "v26.10.1"`,
`commit_sha = ff96f04e…` (lines 6-7); marketplace `marketplace_sha = bf9eccb3…` (line 30);
per-repo rows at 26.9.30-era (lines 38-58). Coordinator may add as SEAM 11.

## 3. ggen.toml / marketplace pins — inspected, NOT release seams
- `/Users/sac/xaas/ggen.toml:21` pack pin `version = "518572b6…"` — pack content SHA, not release.
- `/Users/sac/ash_surface/ggen.toml:8` pack pin `version = "baa5f117…"` — pack content SHA.
- `/Users/sac/ggen-marketplace/marketplace.active.toml:2` `version = "26.9.12"` — active-pack-list
  schema version; changing it trips `verify_msct_profile.py` exact-set refusals. Flag only.
- `/Users/sac/wasm4pm/ggen.toml:10` `version = "26.6.11"` — wasm4pm pack-config version;
  secondary alignment candidate once SEAM 4 lands.

## 4. Consolidated seam list (coordinator applies)

1. `/Users/sac/ash_pplan/mix.exs:4` — `@version "26.10.3"` → `@version "26.10.5"` (tag v26.10.5 at release).
2. `/Users/sac/ash_surface/mix.exs:4` — `@version "26.10.1"` → `@version "26.10.5"`.
3. `/Users/sac/xaas/VERSION` — `26.10.2` → `26.10.5` (consumed by xaas/mix.exs:13).
4. `/Users/sac/wasm4pm/package.json:3` — `"version": "26.9.28"` → `"26.10.5"`.
5. `/Users/sac/xaas/mix.exs:226` — `{:ggen_igniter, "~> 26.10.1"}` → `~> 26.10.5`,
   gated on hex publish of ggen_igniter 26.10.5; until then keep 26.10.1-hex.
6. `/Users/sac/xaas/mix.exs:105` — ash_a2a ref `3325032d…` → `07180bd3…`
   (re-verify local HEAD immediately before applying).
7. `/Users/sac/xaas/mix.exs:109` — ash_r2rml ref `36f25a30…` → `0d5320f6…` (same caution).
8. `/Users/sac/xaas/mix.exs:253` — ash_pplan ref `b9da1ad7…` → `414a393d…` (same caution).
9. `/Users/sac/beam4pm/mix.exs:11` self `26.10.1` → `26.10.5` (optional), plus
   `ash_a2a_dep/0` (mix.exs:128 hex floor `~> 26.9.30` → `~> 26.10`; mix.exs:132 git ref
   `80b77e22…` → `07180bd3…`).
10. `/Users/sac/ash_surface/mix.exs:132-133` — optional `~> 26.9` → `~> 26.10` tightening.

Note on seams 6-8: mix.lock rows regenerate on the coordinator's `mix deps.update`;
do not hand-edit mix.lock.

## 5. Explicitly NOT seams
- zcode-cli 3.14.3-1 and autofde-lab 0.1.0 — independent versioning schemes.
- marketplace.active.toml `version` — pack-list schema version, not a fleet release pin.
- ggen.toml pack pins (xaas `518572b6…`, ash_surface `baa5f117…`) — pack content SHAs.
- ggen-ecosystem/ecosystem.lock.toml — outside lane scope, noted in §2.

## 6. Verification (post-seam, coordinator-run; this lane is READ-ONLY)
- `/Users/sac/xaas`: `mix deps.update ash_a2a ash_pplan ash_r2rml ex4pm ggen_igniter`
  then `mix compile` and the mock gate.
- Falsifier A: `grep -n '26\.10\.1"' /Users/sac/ash_surface/mix.exs` → zero matches after SEAM 2.
- Falsifier B: `grep -n '26\.10\.5' /Users/sac/xaas/VERSION` → one match after SEAM 3.
- Falsifier C: `git -C /Users/sac/xaas grep -n '3325032d' -- mix.exs` → zero matches after SEAM 6.
