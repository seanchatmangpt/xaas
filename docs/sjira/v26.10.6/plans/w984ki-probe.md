# W984ki — unclaimed-family probe: "/" browser-scope controller layer

- Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface` (uncommitted-lane probe; no commit per lane contract)
- Date: 2026-10-08
- Surface: `lib/xaas_web/controllers/page_controller.ex` (`home/2`), `lib/xaas_web/controllers/page_html.ex` + `page_html/home.html.heex`, `lib/xaas_web/controllers/error_html.ex` (the fallback render layer — **no `fallback_controller.ex` exists in this tree**, typed UNSUPPORTED(path), not searched-for fiction)
- Lane build root: `_build-laneW984ki`, pinned toolchain via asdf shims, MIX_ENV=test

## Census dispositions

| Branch | Disposition | Evidence |
|---|---|---|
| `PageController.home/2` render, body content | COVERED | `test/xaas_web/controllers/page_controller_test.exs` ("Peace of mind...") |
| `home/2` `layout: false` branch (app-layout absence) | UNCOVERED → court c1 | existing test asserts body text only; app-layout header absence never asserted |
| `ErrorHTML.render/2` 404 clause body | UNCOVERED → court c2/c3 | residue_court_w984eq p4 asserts status/content-type only; p5 covers ErrorJSON, not ErrorHTML |
| `ErrorHTML.render/2` 500/403 clauses | UNCOVERED → court c2 | no direct render assertions anywhere in test/ |
| Unmatched browser route → ErrorHTML 404 body text | UNCOVERED → court c3 | p4 status-only |

## Court

`test/xaas_web/controllers/page_court_w984ki_test.exs` — ConnCase, real router, zero mocks, one mutation rationale per test.

- **c1** `layout: false` — mutation: drop `layout: false` from `home/2` → app-layout header appears → fail.
  - **Correction during run**: first draft asserted root-layout marker absence (`Phoenix Framework` title) and **failed against real output** — observed truth is that the root layout IS rendered; `layout: false` skips only the app layout (header nav). Court rewritten to assert the actual discriminating marker (`<header class="px-4 sm:px-6 lg:px-8"`), documented in-test.
- **c2** `ErrorHTML.render/2` template→status-message mapping (404/500/403) — mutation: stop delegating to `status_message_from_template/1` → bodies change.
- **c3** unmatched browser route serves "Not Found" HTML body at 404 — mutation: swap error view/template → body changes while status stays 404.

## Gates (real output)

- `MIX_BUILD_ROOT=_build-laneW984ki mix test test/xaas_web/controllers/page_court_w984ki_test.exs` → `Result: 3 passed` (exit 0; first run 2/3 before the c1 correction above).
- Mock gate `scan_mock_usage(["test","lib"])` → `[]` (exit clean).

## Standing

ALIVE (lane-local): 3/3 passing on the lane build root against current working tree. Typed findings: no FallbackController → UNSUPPORTED(path) for that census row; layout semantics corrected from observed output, not prose.

## Cleanup

Lane build root `_build-laneW984ki` deletion attempted post-receipt (see receipt line below).

Receipt: written without commit, per lane contract.
