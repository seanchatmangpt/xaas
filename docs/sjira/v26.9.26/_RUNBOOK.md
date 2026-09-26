# v26.9.26 Wave Runbook — Fabric Truth & Convergence

Date: 2026-09-26. Repo: `/Users/sac/xaas` — ONE canonical checkout, no git
worktrees, no shadow clones, no per-agent repo copies. Lanes are a partition of
files, not directories. Dispatch prompt canonical form: this file's contract
block, verbatim, plus the lane row.

**GIT FORBIDDEN for lanes** (no add/commit/checkout/stash/branch). The
coordinator owns every git transition and commits per lane. Read-only
`git log`/`git show` are allowed.

## Lane map (two lanes never touch one file)

| lane | owned paths | deliverable |
|---|---|---|
| L1 | `docs/sjira/v26.9.26/**` minus `docs/sjira/v26.9.26/audit/**` | wave scaffold: `goal.ttl`, `_RUNBOOK.md`, `prd-ard.md`, `receipts/` |
| L2 | `CHANGELOG.md` | changelog truth (WO-26.9.26-L2) |
| L3 | `CLAUDE.md`, `README.md` | README/CLAUDE truth (WO-26.9.26-L3) |
| L4 | `priv/zcode_plugin/**` | plugin manifest 26.9.26 + gall-work contract sha pin (WO-26.9.26-L4) |
| L5 | `config/**` | config endpoint truth (WO-26.9.26-L5) |
| L6 | `docs/**` minus `docs/sjira/**` | docs tree truth (WO-26.9.26-L6) |
| L7 | `docs/sjira/v26.9.23/receipts/**` | v26.9.23 receipts truth/backfill |
| L8 | `.ggen/**` | marketplace source restore (WO-26.9.26-L8) |
| L9 | `lib/mix/tasks/**` | mix task docs (WO-26.9.26-L9) |
| L10 | `docs/sjira/v26.9.26/audit/**` | audit records (WO-26.9.26-L10) |

Lane-map exception: per-lane receipt files written under
`docs/sjira/v26.9.26/receipts/` are written by the owning lane (the directory
itself is L1 scaffold). Shared seams are resolved here, never in chat.

## Contract block (identical in every dispatch prompt)

- Standing vocabulary: `ALIVE | PARTIAL_ALIVE | BLOCKED | UNKNOWN | UNSUPPORTED | REFUSED_<REASON>`. Standing is observed, never declared; WorkOrder `sj:standing` literals are `"UNKNOWN"` placeholders only.
- WorkOrder identifiers: `WO-26.9.26-L<n>` in `docs/sjira/v26.9.26/goal.ttl`.
- Refusal shapes: typed `REFUSED_<REASON>` (e.g. `REFUSED_NO_AUTHORITY`, `REFUSED_GENERATOR_OWNED`). A request naming authority is not that authority.
- Placeholder conventions: digests as `sha256:<64 hex>`; paths repo-relative in `goal.ttl`, absolute in receipts; no fabricated receipts, no acceptance mocks, no unresolved placeholders on changed production paths.
- Projected files (`vendor/`-style consequences, incl. `.ggen/**`) are never edited by hand: edit the owning source/pack, re-render.
- No secrets in any written file. Claims about the coordinator's already-executed convergence (dd32425 merge, substitution-receipt-binding in origin/main, fabric server restored 2026-09-26) are provenance, not receipts.

## Build isolation (per lane)

Per-lane Elixir builds: `MIX_BUILD_ROOT=_build-lane<N>`. `deps/` stays shared
read-only; never run `deps.get` from a lane. Non-Elixir lanes need no build
root. First action in every dispatch: echo repo + branch + head SHA.

## Integration order (coordinator-only, serialized)

1. Per-lane commits — one atomic commit per lane, purpose-prefixed, after lane completion and audit.
2. `mix test` gate at repo root, run in lane order L2..L10; red → reset the offending lane's commit, mark BLOCKED, repair narrowly, rerun the gate.
3. `VERSION` bump to `26.9.26`.
4. Push.

Never push from a lane. One writer at a time: the coordinator.
