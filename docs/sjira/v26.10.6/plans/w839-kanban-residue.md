# W839 — kanban→xaas rename residue sweep (lib/ + config/)

Wave: v26.10.6 · Lane W839 · Subject: feat/playwright-surface @ a0723bf6 · 2026-10-07

## Scope

`grep -rn "kanban_web\|KanbanWeb\|Kanban\."` across `lib/` and `config/`
(excluding `_build`, `deps`, `node_modules`). Legitimate `:kanban` otp_app
code references excluded per lane contract.

## Per-hit classification

| # | File:line | Hit | Class | Action |
|---|---|---|---|---|
| 1 | `lib/mix/tasks/xaas.release_audit.ex:329` | `# c5f127cc renamed kanban_web -> xaas_web; the audit reference follows.` | (a-variant) historical comment — **not stale**: it accurately documents the rename commit itself; rewriting to remove `kanban_web` would make it false | LEAVE (no edit) |

That is the only hit in lib/ and config/. No `KanbanWeb`, no `Kanban.` module
references, no generated/tracked artifacts, no config keys found.

## Fixes applied

None required. Zero (a)-class stale comments exist; the single hit is a
historically accurate reference to rename commit c5f127cc and is correct as
written.

## Verification

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW839 mix compile --force` → exit 0, "Generated xaas app", no warnings (real tail observed 2026-10-07).
- `_build-laneW839` left in place for coordinator cleanup (deletion denied by permission gate).

## Standing

ALIVE (residue sweep complete; single historical comment, no stale text).
