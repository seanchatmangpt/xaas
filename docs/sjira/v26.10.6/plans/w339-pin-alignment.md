# W339 Pin Alignment — x4 SEAM audit @ xaas feat/playwright-surface

Read-only audit, no edits to mix.lock or any repo. All commands listed inline; every SHA is a real read.

## 1. xaas mix.lock locks (read: `grep -E '"(ash_a2a|...)"' /Users/sac/xaas/mix.lock`)

| dep | lock |
|---|---|
| ash_a2a | `86214551de93fc8ab395f5ed0b84d32922a5d99b` (git, pinned ref) |
| ash_pplan | `5f10c9798b783c2023a6bfaa892c000630476f05` (git, pinned ref) |
| ash_r2rml | `0d5320f6c5e9a43bb3e8dcb0f30d301b1ebb64d7` (git, pinned ref) |
| ex4pm | `9f7aecda87e5110f668f824bbae760f6c97f88e1` (git, pinned ref) |
| ash_surface | path dep — mix.exs `@version "26.10.6"` (grep `@version ~/ash_surface/mix.exs:4`) |
| ggen_igniter | hex 26.10.1 (checksum `c99ad2d8…`, no git pin in xaas mix.lock) |

## 2. Sibling truth (commands: `git -C ~/REPO rev-parse HEAD`; `branch --show-current`; `status --porcelain | wc -l`)

| repo | HEAD | branch | dirty files |
|---|---|---|---|
| ash_a2a | `07180bd3be686db25b61918770a76a003349ba29` | feat/tck-vuln-hardening | 4 |
| ash_pplan | `414a393d17afa6637ce1db5c34fab09e032c58c8` | fix/ggen-verify-header | 9 |
| ash_r2rml | `0d5320f6c5e9a43bb3e8dcb0f30d301b1ebb64d7` | fix/v26.9.29-from-source-head | 4 |
| ex4pm | `9f7aecda87e5110f668f824bbae760f6c97f88e1` | main | 10 |
| ggen_igniter | `7dbcdb3a050ea4b2ce4d5f047ed2913052b5b539` | feat/adr-0010-gate-convention | 63 |
| ash_surface (version only) | — | — | `@version "26.10.6"` |
| wasm4pm | `32deb59f6e40cbf6812f2a9581e545c92b60d1ae` | fix/v26.9.30-ci-fmt-tsc | 26 |
| beam4pm | `813eb92477ecee3ec734ea93269a32a700692057` | main | 2495 dirty (repo-wide artifacts) |

## 3. Lock vs sibling-HEAD diff

| dep | verdict |
|---|---|
| ash_a2a | LAGGED: lock `86214551` < HEAD `07180bd3` |
| ash_pplan | LAGGED: lock `5f10c979` < HEAD `414a393d` |
| ash_r2rml | ALIGNED at HEAD, but sibling has 4 dirty files (not exact-head clean) |
| ex4pm | ALIGNED at HEAD `9f7aecda`, 10 dirty files |
| ggen_igniter | hex 26.10.1 ≠ local HEAD `7dbcdb3a` (63 dirty) — lock cannot express a local git SHA; OPERATOR-GATED |

## 4. VERSION / SEAM versions (all real reads)

| seam | surface | observed | milestone 26.10.6 | verdict |
|---|---|---|---|---|
| SEAM 1 | ash_pplan mix.exs `version:` | `26.10.6` (line 10) | 26.10.6 | ALIGNED |
| SEAM 2 | ash_surface mix.exs `@version` | `26.10.6` (line 4) — matches w19 expectation | 26.10.6 | ALIGNED |
| SEAM 3 | xaas root `VERSION` | `26.10.6` | 26.10.6 | ALIGNED |
| SEAM 4 | wasm4pm | no version read into xaas mix.lock; HEAD `32deb59f`, branch fix/v26.9.30-ci-fmt-tsc, 26 dirty — no xaas pin to align; OPERATOR-GATED |

Marketplace `[active].version = "26.10.6"` (standing CANDIDATE, front_door ggen-platform-pack) — ALIGNED.
ggen `Cargo.toml version = "26.10.6"` — ALIGNED (line 2; workspace version on line 10).

## 5. Verdict table

| pin | verdict |
|---|---|
| ash_a2a | LAGGED (lock `86214551de93fc8ab395f5ed0b84d32922a5d99b` vs sibling HEAD `07180bd3be686db25b61918770a76a003349ba29`) |
| ash_pplan | LAGGED (lock `5f10c9798b783c2023a6bfaa892c000630476f05` vs sibling HEAD `414a393d17afa6637ce1db5c34fab09e032c58c8`) |
| ash_r2rml | ALIGNED (both `0d5320f6c5e9a43bb3e8dcb0f30d301b1ebb64d7`; sibling 4 dirty files — not exact-head clean) |
| ex4pm | ALIGNED (both `9f7aecda87e5110f668f824bbae760f6c97f88e1`; sibling 10 dirty files) |
| ggen_igniter | OPERATOR-GATED (hex 26.10.1 vs local git HEAD `7dbcdb3a…`, 63 dirty — lock mechanism can't pin local git head) |
| ash_surface | ALIGNED (SEAM 2, version 26.10.6) |
| wasm4pm | OPERATOR-GATED (SEAM 4 — no xaas lock pin exists to align) |
| xaas VERSION / ggen / marketplace active | ALIGNED (all 26.10.6) |

Counts: ALIGNED 5 · LAGGED 2 · OPERATOR-GATED 2

No edits performed. This is the x4 SEAM refresh as of 2026-10-06.
