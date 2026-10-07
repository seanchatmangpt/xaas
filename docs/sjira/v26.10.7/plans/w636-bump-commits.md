# W636 — Version-Bump Commit Lane Receipt (v26.10.7 fleet seal)

Date: 2026-10-07. Operator-delegated commit+push in sibling repos (NOT xaas, NOT wasm4pm).
No tags created (tagging lane's job after verification). All pushes fast-forward; all
branches were in sync with origin before commit (verified via `fetch` + `status -sb`).

Message for every commit: `chore(release): bump version to 26.10.7` (via `git commit -F`).

## Per-repo table

| repo | branch | SHA | pushed | notes |
|---|---|---|---|---|
| ash_a2a | feat/tck-vuln-hardening | e0fb769e | Y | `mix.exs` 26.10.5→26.10.7, diff was exactly the bump; no pathspec triage needed |
| gymact | v26926/gymact-land-aloop-execution-kernel | dcda945a | Y | partial-staged ONLY the `pyproject.toml` version hunk (26.9.28→26.10.7) via filtered `git apply --cached`; unrelated hunks left uncommitted (see drift below) |
| ggen | feat/v26.10.5-release-cut | 905d8af33 | Y | committed Cargo.toml (workspace 26.10.6→26.10.7), Cargo.lock (9 version lines: 7 pkgs→26.10.7, ggen-engine + pm4pytest-cli→26.10.6), and the two crate Cargo.tomls matching them — lock and manifests mutually consistent |
| ggen_igniter | feat/adr-0010-gate-convention | c3cd5d2 | Y | partial-staged ONLY the `mix.exs` version hunk (26.10.5→26.10.7); shipped_packs/ash-manufacture-pack change left uncommitted |
| ash_graphlaw | main | 3ecae0e | Y | `mix.exs` @version and `ontology.ttl` glx:packageVersion BOTH 26.10.7 — no drift; commit clean |

## Drift / disclosed residue (NOT committed)

- **gymact `src/gymact/__init__.py`**: `__version__ = "26.10.6"` — one patch behind the
  26.10.7 bump and inconsistent with the committed pyproject 26.10.7. Left uncommitted.
  Needs a W618 follow-up to align to 26.10.7 before tagging (or the tag lane must accept
  the pyproject-only authority).
- **gymact pyproject filterwarnings hunk** and 5 other modified files (CHANGELOG, README,
  docs/reference.md, gyms/ggen.py, surfaces/fastapi.py): unrelated in-flight edits, left.
- **ggen_igniter mix.exs shipped_packs/ash-manufacture-pack hunk**: unrelated in-flight
  edit, left uncommitted.
- **ggen**: other modified files (crates/ggen-engine/src/*, ggen.toml, marketplace.json,
  .specify/repo-facts.ttl, etc.) unrelated, left.
- **ash_graphlaw untracked** `docs/sjira/`: left.

## Standing

All five W618 bump states are committed and pushed: PARTIAL_ALIVE — version surface is
sealed at 26.10.7 in all five repos except the disclosed gymact `__init__.py` 26.10.6
drift. No BLOCKED entries. Exact replay: per-repo `git show <sha>` above; pushes visible
on origin refs. Tagging remains with W635's successor lane.
