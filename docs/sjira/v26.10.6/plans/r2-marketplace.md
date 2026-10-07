# R2 — ggen-marketplace audit & consumer-wiring plan (v26.10.6 convergence, clean regeneration)

Lane: R2 · Repo: `/Users/sac/ggen-marketplace` · Branch `feat/aaif-gcp-roadmap-v26.10.5` @ `93895f808` (full SHA `93895f808775e04dce9441fbf4014a3d4d40c942`, witnessed via `git rev-parse HEAD` this pass).
Read-only audit; the only write in scope is this plan file. No builds, no git mutations.

## 1. Standing (all evidence cited from commands run this pass)

| check | command | actual output |
|---|---|---|
| Tip | `git log --oneline -5` | `93895f808 fix(tests): pin env entry state in test_real_backend_refused_without_permit (EA122)`; then `10320be57 docs(standing): regenerate standing.md at 40d57e219`, `40d57e219 fix(aaif-vanilla-pack): purge residual {{target_scope}} from fixture; regen lock + projection (EA119)`, `2484f65b7 fix(aaif-vanilla-pack): drop target_scope param rejected by goose v1.53.0 recipe schema (EA116)`, `93f4ca55c docs(pr): refresh pr-body-v26.10.5 stats to tip 5a8ddf0b8` |
| Working tree | `git status --short` | empty (clean) |
| Pack count | `ls packs/ \| wc -l` | `305` packs on disk |
| Consumer pin ancestry | `git merge-base --is-ancestor` | `518572b6` (xaas castle-bridge pin) → **YES ancestor of tip**; `baa5f117` (ash_surface ash-extension pin) → **YES ancestor of tip** |
| Pin drift for castle-bridge | `git rev-list --count 518572b6..HEAD -- packs/xaas-castle-bridge-pack` | `1` (commit `0ce47cc39 fix(packs): make all 376 packs qualify through real ggen 26.9.28` touches the pack since the pin) |
| Pin drift for ash-extension | `git rev-list --count baa5f117..HEAD -- packs/ash-extension-pack` | `31` commits touch `packs/ash-extension-pack` since the pin (e.g. `6b86bdaa0`, `f9bcad835`, `4361130f0`) |
| Frozen court identity | `marketplace.toml [ggen]` | `version = "v26.8.11"`, `release_commit = 402cecdff8784767eb9f26e235d87c759610c066` — with the inline note: `2026-10-05: pin-bump requested and refused — BLOCKED:pin-bump-user-gated`. Bump procedure staged in `docs/context/ggen-pin-bump.pending.md` (also notes v26.10.5 tag local-only in ~/ggen, assets unpublished) |
| v26.10.5 cycle receipt | `docs/context/v26.10.5-receipt.md` (exists at tip, 213 lines) | FINAL receipt: 65 commits, 224 files, +10594/−1183 over base `3ddbfeb7`; frozen re-confirm at `57f51ca2` (295 ALIVE / 9 accepted-WARN / 1 honest SKIPPED per prior audit) |
| Active-set cardinality guard | `grep -rn EXPECTED_ACTIVE_PACKS scripts/*.py` | present in `scripts/verify_enterprise_kudzu_profile.py` (line 12) and `scripts/verify_msct_profile.py` (line 10), exact-set refusal at kudzu lines 218–222 (`missing=… extra=…`) |
| Catalog spec (consumer) | `ls /Users/sac/xaas/e2e \| grep -i market` | `marketplace.spec.ts` |
| ash_surface consumer | `ls /Users/sac/ash_surface/e2e` | no such directory (exit 1) — **no Playwright surface at all in ash_surface** |

## 2. Front-door state: `marketplace.active.toml`

```
version      = "26.9.12"
standing     = "CANDIDATE"
front_door   = "ggen-platform-pack"
packs        = [13 packs: aaif-vanilla, decision-optionality, enterprise-governance,
                evidence-standing, experience-projection, ggen-platform,
                marketplace-governance, planning-policy, process-intelligence,
                protocol-integration, repository-lifecycle, semantic-projection,
                state-transition]
[legacy] frozen-evidence mode, ABSORB/FIXTURE/DROP classification
```

Trailing comment block records the 2026-10-04 candidate wave (a2a-* and sa2a-* packs with
manifests on disk but NOT in `[active].packs`; every addition UNKNOWN, gated on the two
`EXPECTED_ACTIVE_PACKS` profile verifiers). `ggen-platform-pack/pack.toml` itself carries
`version = "26.9.30"`.

### Version-field drift (three-way, live on disk this pass)

| field | value |
|---|---|
| `[active].version` (marketplace.active.toml:2) | `26.9.12` |
| `[marketplace].version` (marketplace.toml) | `v26.10.2` |
| `[ggen].version` (marketplace.toml) | `v26.8.11` (frozen court, BLOCKED bump) |
| `docs/reference/standing.md` tail | historical v26.9.13 record explicitly marked "Historical, not current" |
| `docs/context/standing.md` | regenerated at `40d57e219` (commit `10320be57`) |

This drift is benign-but-real: `[marketplace].version` is the registry snapshot id,
`[active].version` is the active-scope label, `[ggen].version` is the pinned court
binary. Only `[active].version = 26.9.12` is stale relative to the v26.10.x cycle.

## 3. Pack surface and consumer wiring (mission: fleet converged at v26.10.6 via xaas + ash_surface, closure only)

### xaas (`/Users/sac/xaas/ggen.toml`)

- `[project] name = "xaas"`; `[ontology] source = "ontology.ttl"`.
- Exactly one locked remote pack: `[packs.xaas_castle_bridge]` →
  `packs/xaas-castle-bridge-pack` @ `518572b6b53103922ae8a27636a00e982a0907c4`, git+subdir resolver.
- Vendored lineage: `packs/xaas-ash-core-pack` ontology predating remote-pack support
  (deliberately preserved per the ggen.toml header comment).
- `ggen.toml` header states new reusable capabilities MUST prefer locked marketplace packs.
- No `ggen.lock` file exists at the xaas root (`ls ggen.lock*` → no matches) — lock state
  is therefore whatever the last sync receipt recorded, not a committed lockfile.
- Playwright surface: `/Users/sac/xaas/e2e/marketplace.spec.ts` (catalog read projection
  of the 13-pack `[active]` set; only Playwright-validated marketplace surface in the fleet).
- Render state of castle-bridge: UNKNOWN (no `ggen sync` run — forbidden this pass).

### ash_surface (`/Users/sac/ash_surface`, branch `main` @ `db5a8899`)

- `[packs]` pins `ash-extension-pack` @ `baa5f117deefb3b84f7bd653e65e9fe8d9b1d2fa` via git+subdir.
- `baa5f117` is an ancestor of tip but **31 commits behind tip content** for
  `packs/ash-extension-pack` — including `6b86bdaa0` (frontmatter-less template refusals
  fixed under frozen-ggen court) and `f9bcad835` (deterministic GROUP_CONCAT folds).
  The pinned snapshot predates those qualification fixes; render state at pin UNKNOWN (no sync run).
- No `e2e/` directory — zero Playwright validation on the ash_surface side.

### Resolution verdict

| consumer | pack | resolves at tip? | gap |
|---|---|---|---|
| xaas | xaas-castle-bridge-pack @ 518572b6 | Yes (ancestor; content 1 commit behind tip for that subdir) | optional re-pin to 93895f808 after sync-receipt replay |
| xaas | xaas-ash-core-pack (vendored) | Yes (in-tree) | none — documented deliberate exception |
| ash_surface | ash-extension-pack @ baa5f117 | Yes (ancestor; content 31 commits behind tip for that subdir) | re-pin recommended; snapshot predates 2 qualification fixes |
| neither | 13-pack `[active]` set | projected via catalog only (xaas e2e spec) | candidate a2a-*/sa2a-* wave still UNKNOWN, gated on EXPECTED_ACTIVE_PACKS |

## 4. Exact proposed closure edits (implementer executes; not done this pass)

1. **Bump `[active].version`** in `/Users/sac/ggen-marketplace/marketplace.active.toml`:
   `version = "26.9.12"` → `version = "26.10.6"`. This is the stale label; the exact-set
   profile verifiers do not check this field (they check the packs set only), so no
   `EXPECTED_ACTIVE_PACKS` change is needed for a version-only bump. Verify with
   `python3 scripts/marketplace.py validate` + `catalog` after edit.
2. **Re-pin ash_surface** `/Users/sac/ash_surface/ggen.toml`:
   `version = "baa5f117deefb3b84f7bd653e65e9fe8d9b1d2fa"` → `version = "93895f808775e04dce9441fbf4014a3d4d40c942"`,
   then run `ggen sync` and diff the projection; keep the old pin if the projection drifts
   beyond the two qualification-fix commits (falsifier: byte-diff of generated output at
   old pin vs new pin).
3. **Re-pin xaas castle-bridge** (optional, lower priority): `518572b6…` → `93895f808…`;
   the single intervening commit `0ce47cc39` claims fleet-wide qualify-green under
   ggen 26.9.28, so drift risk is low. Same falsifier: sync at old vs new pin, byte-diff.
4. **Do NOT touch** `[ggen].version = "v26.8.11"`: bump remains
   BLOCKED:pin-bump-user-gated (inline refusal in marketplace.toml) plus
   BLOCKED:release-artifacts (per `docs/context/ggen-pin-bump.pending.md`: v26.10.5 tag
   local-only, assets unpublished, digests unknown). Only the user can lift this.
5. **Do NOT expand** `[active].packs`: the 2026-10-04 candidate wave stays UNKNOWN until
   each pack passes `python3 scripts/marketplace.py check <pack>` AND the two
   `EXPECTED_ACTIVE_PACKS` verifiers are updated first (kudzu refusal shape:
   `missing=… extra=…`).
6. **Regenerate `docs/context/standing.md`** after edits 1–2 (regen tool landed at
   `40d57e219`/`10320be57`; standing.md regeneration is already the repo's normal post-edit step).

## 5. Risks

- **Pinned snapshots are not tip**: both consumer pins are ancestors (safe, compatible)
  but behind-tip (castle-bridge 1 commit, ash-extension 31 commits). Rendering at pin is
  the qualified state; re-pinning moves the court subject and requires a fresh sync receipt.
- **Frozen court identity skew**: the marketplace qualifies packs under ggen v26.8.11 while
  the fleet's ambient ggen and ggen_igniter hex are 26.10.x — the pin-bump is user-gated,
  so qualification-identity skew persists into v26.10.6 closure unless the user lifts it.
- **No committed lockfile in xaas**: absent `ggen.lock`, closure replay of xaas's pack
  closure depends on sync receipts, not a committed lock — weaker replay.
- **`[active].version` bump is cosmetic but touches a file gated by profile verifiers**
  (they read the packs set, not the version field — verified by grep of refusal sites —
  but run both verifiers after the edit anyway).
- **ash_surface has no e2e surface**: any ash-extension re-pin is validated only by
  `ggen sync` output diff, not by any Playwright court.
- **Catalog spec depends on `[active]` set stability**: `/Users/sac/xaas/e2e/marketplace.spec.ts`
  courts the 13-pack projection; any accidental pack-set edit breaks that court — keep
  edit 1 strictly version-only.
- **R2 prior-audit artifact risk is closed**: this file is a clean regeneration from live
  command output this pass; the killed r2 rewrite's garbled path/version transcription is
  not inherited.
