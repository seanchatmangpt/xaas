# W650p — ggen-marketplace version-commit lane (v26.10.7 fleet seal)

Standing: **ALIVE** for the version-commit transition (bump → validate →
commit → push → tag → push-tag, all witnessed). This resolves the last of
W648's BLOCKED pair (ash_surface sealed by W650o; ggen-marketplace sealed
here).

## Subject

- Repo: `/Users/sac/ggen-marketplace`, branch
  `feat/aaif-gcp-roadmap-v26.10.5` (the branch W642/W642b's pack work
  landed on and was pushed to; current branch at lane start)
- Commit: `308427c3a` — "v26.10.7 — marketplace version bump (W650p)"
  (2 files: `CHANGELOG.md` +12, `marketplace.active.toml` ±1)
- Tag: `v26.10.7` (annotated) on `308427c3a`, pushed;
  `git ls-remote` peel verified: `refs/tags/v26.10.7^{}` =
  `308427c3a2f3ef7a725255f115e577fcbc8adb35`
- Push: fast-forward `969ab0e1a..308427c3a` (no force), then
  `* [new tag] v26.10.7 -> v26.10.7`

## Grounding

- `[active].version` was `26.9.12` at HEAD with an uncommitted working-tree
  bump to `26.10.6` (W618-era, matching W648's flag). Absorbed and advanced
  to `26.10.7`.
- W642/W642b pack work confirmed already landed and pushed on this branch
  (HEAD at lane start `969ab0e1a` "ci(aaif): harden Chicago integration
  court workflow…"; parent `5fc3e96fd` W642 render surfaces).

## Per-file table (the version commit, `git show --stat HEAD`)

| File | Change | Content |
|---|---|---|
| `CHANGELOG.md` | +12/-0 | new `[v26.10.7] — 2026-10-07` entry: version-advance + validation bullets; retained W126's pending pack-fix bullets under the entry, relabeled `(W126 lane; ash-extension-pack edits uncommitted pending pack commit + pin advance…)` |
| `marketplace.active.toml` | `version = "26.10.6"` → `"26.10.7"` | version field only; 13-pack active set and `front_door = "ggen-platform-pack"` byte-unchanged |

## Validation (real commands, real output)

- `python3 scripts/verify_msct_profile.py` → exit 0, `MSCT/MX profile
  invariants: ALIVE / active_packs=13 front_door=ggen-platform-pack`
- `python3 scripts/verify_enterprise_kudzu_profile.py` → exit 0,
  `Enterprise Kudzu profile invariants: PARTIAL_ALIVE / active_packs=13`
- `python3 scripts/marketplace.py validate --scope active` → exit 0 on the
  **exact commit subject**: `validated packs=306 manifests=306
  ontologies=504 templates=1837 native_gates=1868 verifier_gates=21
  profiles={"project":101,"projection":159,"semantic":46} diataxis=20`.
  Method: clean `git archive HEAD` extract + overlay of the two version
  files into `/tmp/w650p-subject` (the subject as it will exist at the tag),
  validator run there.
- Disclosed: the same validator run **in-place in the checkout** exits 2
  with `REFUSED:MANIFEST_MISSING:.clap-noun-verb` /
  `REFUSED:ONTOLOGY_SOURCE_MISSING:.clap-noun-verb` — a git-ignored runtime
  cache dir `packs/.clap-noun-verb/` (ocel.json/receipts.jsonl, mtime today
  12:21, another lane's ggen run) that `marketplace.py`'s
  `PACKS.iterdir()` does not skip. Pre-existing hidden-dir blindspot in the
  validator, independent of this lane's diff (verified by the clean-subject
  run passing). Candidate fix: skip dot-dirs in the iterdir scan — left to
  a separate transition.

## Left uncommitted (NOT this lane's, enumerated)

- Tracked-modified (3): `packs/ash-extension-pack/gates/120_spark_dead_surface.rq`,
  `packs/ash-extension-pack/ontology.ttl`,
  `packs/ash-extension-pack/templates/extension.ex.tmpl` — W126 lane's pack
  fixes, pending their pack commit.
- Untracked (2): `.tool-versions`, `_UNIFIED_WASM_PACK_RECEIPT.md`.

## Replay

```
cd /Users/sac/ggen-marketplace
git show --stat 308427c3a                      # 2 files, version content only
git show v26.10.7 --no-patch                   # annotated tag on 308427c3a
git ls-remote origin v26.10.7 'v26.10.7^{}'    # peel = 308427c3a…
grep version marketplace.active.toml           # version = "26.10.7"
python3 scripts/verify_msct_profile.py; echo $?
python3 scripts/verify_enterprise_kudzu_profile.py; echo $?
```
