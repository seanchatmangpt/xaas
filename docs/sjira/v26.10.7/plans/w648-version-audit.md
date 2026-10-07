# W648 — Final Pre-Tag Version Audit (v26.10.7 fleet seal)

Lane W648, 2026-10-07. Read-only audit across all 22 fleet siblings; no commits, no pushes, no tags minted by this lane.
Method: live `git ls-remote --tags` per repo + working-tree version reads + `git diff HEAD` on version-bearing files,
reconciled against W635 (fleet-tag), W636 (bump commits), W636b (gymact drift), W623 (tag reconciliation), W641a/b.

## Fleet version-source map (observed)

- mix.exs `@version`/`version:` — ash_* family, ggen_igniter
- VERSION file + mix.exs (reads VERSION) — xaas
- Cargo `[workspace.package]` — ggen, ferroplan, affidavit, wasm4pm (workspace member)
- package.json (npm workspace) — wasm4pm, zcode-cli
- pyproject + `src/gymact/__init__.py` — gymact (dual source; W636b synced)

## 22-row audit table (live, this session)

| # | repo | version source | on-disk NOW | committed at HEAD? | tag v26.10.7 local | tag v26.10.7 remote | branch state | uncommitted version drift |
|---|------|----------------|-------------|--------------------|--------------------|---------------------|--------------|---------------------------|
| 1 | xaas | VERSION (mix.exs reads it) | 26.10.7 | YES (56325fa5 bump seal) | no (v26.10.6 only) | no | SYNCED (origin/feat/playwright-surface, 0 unpushed) | none on VERSION; mix.exs drift is wasmex dep, not version |
| 2 | ash_pplan | mix.exs @version | 26.10.7 | YES (862f0c0, main) | YES | YES (37a736f6, peels 862f0c0) | SYNCED (fix/ggen-verify-header 110f5d6) | none |
| 3 | ash_a2a | mix.exs version: | 26.10.7 | YES (e0fb769e) | no | no | SYNCED (feat/tck-vuln-hardening) | none (only untracked docs/thesis/, w608 court test) |
| 4 | gymact | pyproject + `__init__.py` | 26.10.7 / 26.10.7 | YES (pyproject @ dcda945a, `__init__` @ 8472ffd2) | YES | YES (62835e7c, peels 8472ffd2) | SYNCED (v26926/…execution-kernel) | pyproject drift is filterwarnings hunk, not version |
| 5 | ggen | Cargo [workspace.package] | 26.10.7 | YES (905d8af33) | no | no | SYNCED (feat/v26.10.5-release-cut) | none on Cargo.toml; 8 unrelated src edits in flight |
| 6 | ggen_igniter | mix.exs version: | 26.10.7 | YES (c3cd5d2) | no | no | SYNCED (feat/adr-0010-gate-convention) | mix.exs drift is shipped_packs comment/code hunk, not version |
| 7 | ggen-marketplace | marketplace.active.toml `version` | 26.10.6 | NO — bump 26.9.12→26.10.6 sits uncommitted | n/a | n/a | SYNCED (feat/aaif-gcp-roadmap-v26.10.5) | YES — marketplace.active.toml version bump uncommitted (W618-era) |
| 8 | wasm4pm | package.json (npm ws) / Cargo ws 26.9.30 | 26.10.7 / 26.9.30 | package.json YES (986e5daa1) | no | no | SYNCED (fix/v26.9.30-ci-fmt-tsc) | none on package.json; Cargo ws version on own cadence (26.9.30) |
| 9 | zcode-cli | package.json | 3.14.3-1 | YES | n/a | n/a | SYNCED (fix/v26926-preview-publish-typed-skip) | none on version file |
| 10 | autofde-lab | pyproject `dynamic = ["version"]` | dynamic (setuptools) | n/a | n/a | n/a | SYNCED (feat/doctrine-lab) | none |
| 11 | ash_graphlaw | mix.exs @version + ontology.ttl glx:packageVersion | 26.10.7 | YES (3ecae0e, both surfaces) | no | no | SYNCED (main) | none on version surfaces |
| 12 | affidavit | Cargo [package] | 26.10.5 | YES | n/a | n/a | SYNCED (feat/advanced-witness-capability-set) | none on version file |
| 13 | ash_dspy | mix.exs @version | 26.9.25 | YES | n/a | n/a | SYNCED | none |
| 14 | ash_kudzu | mix.exs @version | 0.1.0 | YES | n/a | n/a | SYNCED | none |
| 15 | ash_planning_center | mix.exs @version | 26.9.10 | YES | n/a | n/a | SYNCED | none |
| 16 | ash_expo | mix.exs @version | 0.1.0-dev | YES | n/a | n/a | SYNCED (test/end-to-end-codegen) | none on version file |
| 17 | ash_autofde | mix.exs @version | 26.10.1 | YES | n/a | n/a | SYNCED (main; priv/wasm unreadable — sandbox perms, not drift) | none |
| 18 | ash_atlassian | mix.exs @version | 26.9.28 | YES | n/a | n/a | SYNCED | none |
| 19 | ash_r2rml | mix.exs @version | 26.9.28 | version surfaces clean | no | no | SYNCED (fix/v26.9.29-from-source-head) | none on version file |
| 20 | ash_affidavit | mix.exs @version | 26.10.1 | YES | n/a | n/a | SYNCED (feat/signing-surface) | none |
| 21 | ferroplan | Cargo [workspace.package] | 0.29.0 | YES | n/a | n/a | SYNCED (main) | none on version file |
| 22 | ash_surface | mix.exs @version | 26.10.6 | NO — bump 26.10.1→26.10.6 uncommitted | n/a | n/a | SYNCED (main, 91 dirty files) | YES — @version 26.10.1→26.10.6 uncommitted, plus version_sync tests + bump_version.sh (W618-era) |

## Seal verdict

- **TAGGED NOW (2)**: ash_pplan, gymact — v26.10.7 local+remote, peels to a commit whose version surfaces say 26.10.7.
- **TAG-READY NOW (6)** — version committed at HEAD, pushed (0 unpushed, upstream-synced), zero version drift: xaas, ash_a2a, ggen, ggen_igniter, wasm4pm, ash_graphlaw.
- **PENDING TAGS (6)**: the 6 tag-ready repos above — the tagging successor tags the branch HEAD exactly:
  - xaas `feat/playwright-surface` @ 56325fa5 (VERSION 26.10.7)
  - ash_a2a `feat/tck-vuln-following` — **correct: `feat/tck-vuln-hardening`** @ e0fb769e
  - ggen `feat/v26.10.5-release-cut` @ 905d8af33
  - ggen_igniter `feat/adr-0010-gate-convention` @ c3cd5d2
  - wasm4pm `fix/v26.9.30-ci-fmt-tsc` @ 986e5daa1
  - ash_graphlaw `main` @ 3ecae0e
- **BLOCKED (2)**:
  - ash_surface: version bump 26.10.1→26.10.6 uncommitted (91 dirty files in checkout). Its cadence target is
    26.10.6, not 26.10.7 — a version-commit lane must commit the bump before any tag.
  - ggen-marketplace: marketplace.active.toml 26.9.12→26.10.6 uncommitted; same treatment (target 26.10.6).
- **OWN CADENCE, NO v26.10.7 OBLIGATION (8)**: zcode-cli (3.14.3-1), autofde-lab (dynamic), affidavit (26.10.5),
  ash_dspy (26.9.25), ash_kudzu (0.1.0), ash_planning_center (26.9.10), ash_expo (0.1.0-dev), ash_autofde (26.10.1),
  ash_atlassian (26.9.28), ash_r2rml (26.9.28), ash_affidavit (26.10.1), ferroplan (0.29.0).
  W641a (affidavit) BLOCKED(pack-contract-divergence) and W641b (ferroplan) BLOCKED(pack-capability-missing) were
  pack-migration lanes, not version lanes — neither bumped versions by design; honest record: these repos were
  never part of the W618 26.10.7 bump set, so their versions are correct at their own cadence.

## Tagging successor's exact work list

1. Tag the 6 tag-ready repos at the exact HEAD SHAs listed above (annotated: `git tag -a v26.10.7 -m … && git push origin v26.10.7`).
2. Do NOT tag ash_surface / ggen-marketplace until their 26.10.6 version bumps are committed by a version-commit lane.
3. gymact tag peels to 8472ffd2 (includes W636b `__version__` sync — verify confirmed, remote `v26.10.7^{}` = 8472ffd2).
4. After tagging, newest-tag probes must use `sort -V` (W623 guard) — never `tag -l | tail`.

## Standing

- Per-repo observations: ALIVE (live `ls-remote` + working-tree reads on exact subjects, this session).
- Tag-ready set (6 repos): PARTIAL_ALIVE until tags minted — the falsifier for "tag-ready" is a failed
  `git tag -a` on any listed SHA (branch moved), which the successor must re-verify before tagging.
- BLOCKED rows: BLOCKED(version-commit-pending) ×2 (ash_surface, ggen-marketplace).
- Own-cadence rows: recorded honestly as out-of-scope for the v26.10.7 seal (not BLOCKED — never in the bump set).
