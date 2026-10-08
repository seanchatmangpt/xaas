# W984ga — unclaimed-family probe: `Xaas.Generator` fixture factory

Lane W984ga · branch `feat/playwright-surface` · 2026-10-07 · no commit (per dispatch)

## Location correction

Dispatch named `lib/xaas/generator/` — that directory does not exist on this
subject. The actual family is the test-support factory at
`test/support/generator.ex` (`defmodule Xaas.Generator`, Ash.Generator-based,
the `create_org!` factory W984ei used). Probe re-aimed there.

## Per-function dispositions

| function | disposition |
|---|---|
| `user/1`, `create_user!/1` | covered — heavy wrapper use (e.g. `test/xaas_web/ocel_envelope_avatars_test.exs` exercises the explicit-email `normalize_email/1` branch). Remaining unexercised branch (no-attrs empty-`normalize_email` path + email sequence distinctness) newly courted below. |
| `book/1`, `create_book!/1` | covered — wrappers + `available_copies`/`total_copies` overrides exercised (avatars tests). Court adds a persisted-override assertion. |
| `org/1`, `create_org!/1` | covered for happy path (dozens of controller tests). **Uncovered state-bearing branch: explicit duplicate-slug override vs `identity(:unique_slug)` typed failure** — newly courted. |
| `provider/1`, `create_provider!/1` | covered for happy path. **Uncovered: real-org-slug coupling** (default `org_id` is the placeholder `"org-generated"`; no test bound a provider to a real org through the generator) — newly courted. |
| `webhook/1`, `create_webhook!/1` | covered for happy path (`webhook_deepening_test.exs` etc.). **Uncovered: `enabled: false` override persisting** — newly courted. |
| `pending_approval!/4` | covered — widely used incl. non-default resources (`ApprovalBackupRetentionChange`, `ApprovalPricingOverride` controller/governance tests). Typed COVERED, no new court needed. |

## Court file

`test/xaas/generator/family_court_w984ga_test.exs` — 5 tests, real Postgres
via SQL sandbox, real Ash actions, zero mocks. Mutation rationale per test in
the moduledoc: drop the Org `:unique_slug` identity / break
`changeset_generator` overrides passthrough / drop the email sequence →
exactly this file fails, tree stays green.

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ga mix test test/xaas/generator/family_court_w984ga_test.exs` → `Result: 5 passed` (fresh lane build, ~18 min deps compile + 1.0 s tests)
- Mock gate: `scan_mock_usage(["test","lib"])` → `[]`, exit 0
- `rm -rf _build-laneW984ga` → **rm OK** (lane build lease deleted; not denied)

## Notes

- First run: 3/5 (wrong expected error class `Ash.Error.Framework` — real
  class is `Ash.Error.Invalid` "has already been taken"; `String.contains?/2`
  on `Ash.CiString` email). Fixed against real output; final 5/5.
- No shared files touched; new file only. In-flight siblings in git status
  untouched and disjoint from `test/xaas/generator/`.
