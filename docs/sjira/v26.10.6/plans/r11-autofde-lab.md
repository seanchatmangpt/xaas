# R11 — autofde-lab fleet convergence audit (v26.10.6, closure only)

Lane R11, v26.10.6 fleet convergence audit. READ-ONLY survey; this file is the
only artifact written.

Subject: `/Users/sac/autofde-lab` @ `feat/doctrine-lab` @ `2a3d064e30df4da2bf465a2fbaaefe6e84da0325`
(`feat(aaif): integrate AAIF vanilla runtime, FastMCP server, and A2A handler`, 2026-10-05).

## Standing (real evidence)

| surface | standing | evidence |
|---|---|---|
| autofde-lab repo head | ALIVE (repo-level) | real checkout `feat/doctrine-lab` @ 2a3d064e; clean tree except 2 gitlink-smudged submodules |
| xaas → autofde-lab read path | ALIVE | `/Users/sac/xaas/lib/xaas/autofde/status_parser.ex` — `@default_path Path.expand("../autofde-lab/docs/STATUS.md", File.cwd!())`; `/Users/sac/autofde-lab/docs/STATUS.md` observed on disk (2026-10-06) |
| StatusLive surface | ALIVE | `lib/xaas_web/live/autofde_lab/status_live.ex`, route `lib/xaas_web/router.ex:284` (`live("/dashboards/autofde-lab", ...)` under `/dev` scope gated on `Application.compile_env(:xaas, :dev_routes)`) |
| StatusLive ExUnit coverage | ALIVE | `test/xaas_web/live/autofde_lab/status_live_test.exs` — real ConnCase mount, real `Xaas.Repo` sandbox shared mode, real `WebhookDelivery` rows |
| StatusLive Playwright coverage | ALIVE (corrects lane brief) | `e2e/autofde-wait` — actually `e2e/autofde-lab.spec.cjs` (2 tests: benchmark-history panel + webhook-deliveries panel, asserts real STATUS.md-derived passes or typed not-found banner); wired via `playwright.config.cjs` `testDir: "./e2e"`; not gated by name in config, picked up by testDir |
| xaas ultracode program wiring | PARTIAL_ALIVE | `config/dev.exs:190-196` declares program `"autofde-lab"` (sensing `autofde-lab-jira`, suites `autofde-lab-dod`/`autofde-lab-canonical`) but `path: Path.expand("~/xaas/worktrees/repos/autofde-lab")` — `~/xaas/worktrees/repos/` does NOT exist on disk (observed 2026-10-06: `ls` → ENOENT). Program is declared but its declared subject path is absent, so the loop cannot resolve the canonical checkout at `/Users/sac/autofde-lab` |

Corrections to the lane brief are flagged inline above and below.

## Gaps to wiring doctrine-lab through xaas / ash_surface

1. **Stale program path in `config/dev.exs`** — the declared autofde-lab program
   points at `~/xaas/worktrees/repos/autoffe-lab` (typo-risk note: actual string is
   `~/xaas/worktrees/repos/autofde-lab`), a path that does not exist. Under the
   one-canonical-checkout law the correct subject is `/Users/sac/autofde-lab`.
   Consequence: the ultracode loop's program registry resolves the program but
   cannot materialize the subject (ENOENT at refresh), so autofde-lab is
   effectively unwired for fleet convergence at v26.10.6.
2. **No ash_surface surface on autofde-lab** — grep across
   `ggen.toml`, `src/`, `mcp/`, `integrations/` for `ash_surface|AshSurface`
   returns zero hits; ash_surface @ `db5a889` (feat/surface branch head) has zero
   autofde-lab references. The wiring is xaas→autofde-lab only, one-directional,
   file-read (`STATUS.md` parse) + webhook-delivery panel. No digest, no
   projection, no AshSurface digest of autofde-lab capability.
3. **One-way, parse-only integration** — `Xaas.Autofde.StatusParser` reads a
   human-narrative markdown dispatch sheet (`docs/STATUS.md`), with
   regex-shaped `Last/Prior update: **pass N**` and `## Pass N —` headings.
   Fragile to narrative drift (the parser already special-cases two heading
   shapes; verdict inference from summary text via negative-signal regex).
4. **Dirty files (inventory only, untouched)** — `vendor/gyms/enterprisebench`
   and `vendor/gyms/sregym` modified (0-line gitlink smudge from submodule
   checkout state, not content change). Do not touch; a closure round should
   `git submodule update` or leave as-is per coordinator.
5. **No v26.10.6 marker in autofde-lab** — `docs/jira/` tops out at v26.9.23;
   no v26.10.x jira dir, no v26.10.6 pointer. Convergence is xaas-side only.

## Proposed edits (closure round, small coherent diff)

1. `config/dev.exs` — re-point program `"autofde-lab"` `path:` to the canonical
   checkout: `Path.expand("~/autofde-lab")` (matches the sibling-repo pattern
   already used by `Xaas.Autofde.StatusParser`'s `../autofde-lab` sibling
   resolution from the xaas cwd). Also re-point the other programs whose
   declared paths under `~/xaas/worktrees/repos/` are ENOENT (xaas, gymact,
   ggen-igniter, ggen-ecosystem, gym-ecosystem rows share the same dead
   prefix) — or scope R11 to the autofde-lab row only and file the
   dead-prefix pattern as a separate order. R11 scope: autofde-lab row only.
2. `config/dev.exs` — keep sensing/suites as declared
   (`autofde-lab-jira` → `{"type" => "jira_dir", "dir" → "docs/jira"}` at line
   338; suites in `Xaas.Ultracode.TargetSuites.sj_program_suites/0`). No edit.
3. Optional (explicitly deferred, not R11 scope): ash_surface digest surface for
   autofde-lab capability (AAIF FastMCP server, A2A handler at 2a3d064e) —
   `AshSurface.Digest.content_digest` over the AAIF surface manifest. Defer
   with a typed note; not closure-only.
4. Playwright coverage: **already exists** (`e2e/autofde-lab.spec.cjs`, 2 tests,
   real dev-server route). No edit needed. Correction to the lane brief stands
   on this evidence.

## Risks

- **compile-time dev gate**: the `/dev/dashboards/autofde-lab` route is gated on
  `Application.compile_env(:xaas, :dev_routes)` — flipping requires recompile.
  Any closure edit must not move the route out of the dev scope.
- **STATUS.md narrative fragility**: the parser regexes two heading shapes;
  the 2a3d064e commit touched `docs/STATUS.md` (+22 lines, same shapes per the
  parser passing tests). Risk that a future AAIF pass entry breaks the
  `Last update: **pass N**` shape; a court asserting the real STATUS.md parses
  to ≥1 entry would guard this.
- **dev.exs re-point risk**: `refresh: true` on the program means the loop will
  `git fetch` + fast-forward `/Users/sac/autofde-lab` on next loop run — this
  mutates the canonical checkout during an open branch `feat/doctrine-lab` with
  2 dirty files. Mitigation: drop `refresh: true` for the autofde-lab row, or
  land the edit after the branch merges.
- **submodule smudge**: `git submodule update` on the two dirty vendor gitlinks
  could change pinned SHAs; leave to coordinator, not R11.
- **xaas toolchain discipline**: any `mix` invocation under the wrong toolchain
  corrupts `_build`; use the pinned asdf elixir 1.20.2-otp-28.

## Receipt

- Subject: /Users/sac/autofde-lab @ 2a3d064e (feat/doctrine-lab); xaas @ d1db2b03 (feat/playwright-surface).
- Commands: `git log/status/diff`, `ls`, `grep`, file reads — all read-only.
- Standing: PARTIAL_ALIVE for "autofde-lab wired through xaas" — the read path
  (STATUS.md → StatusLive → Playwright + ExUnit courts) is real and observed;
  the ultracode program wiring is declared but its declared path is ENOENT.
- Falsifier for the closure edit: with the dev.exs path re-point landed, the
  loop's program registry resolves `/Users/sac/autofde-lab` (no ENOENT) and the
  existing playwright suite still passes against the dev server.
