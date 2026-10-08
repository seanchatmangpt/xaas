# W467 — release-audit pin drift receipt

Repo: /Users/sac/xaas @ feat/playwright-surface. Read-only lane; no source edits.

## Finding: STALE-PIN (severity: MEDIUM — fail-closed, not false-green)

`mix xaas.release_audit` is pinned to the v26.8.21 release contract and
**cannot pass at VERSION 26.10.6** — `check_version/1` refuses. The good news:
it fails closed (a green run today is impossible), so the drift type is
"unusable baseline / refusal spam", not "audit proving less while green".

### Pin location and what it governs

- `lib/mix/tasks/xaas.release_audit.ex:14` — `@version "26.8.21"` (module attribute).
- Governed checks:
  - `:85-98` `check_version/1` — requires `VERSION` file AND `Mix.Project.config()[:version]` == `@version`. `mix.exs:13,18` derives mix version from the VERSION file (`26.10.6`), so BOTH sub-checks fail at HEAD → 2 findings → `Mix.raise` at `:72`.
  - `:300-313` `check_release_docs/1` — requires `docs/PRD-v26.8.21.md` exists and contains `"XaaS v26.8.21"`. File still exists at HEAD, so this passes only because the old PRD is retained; it is a frozen-era assertion.
  - `:14` also interpolated into the success line (`:67`) and failure raise (`:72`).
- Frozen-era literals co-pinned with the version (NOT made stale by VERSION alone,
  but part of the same v26.8.21 snapshot):
  - `:24-32` `@resource_counts` (Accounts 5 / Billing 7 / Governance 28 / Ledger 4 / Marketplace 2 / Operations 18 / Platform 7) and `:138` hard total `70`.
  - `:34-41` `@stale_claims` regexes ("69-total-resources", "56-of-69", "all-6-real-domains", "44-of-49", etc.) — these guard against *v26.8.21-era* stale docs; they remain valid as anti-regression regexes even after a version bump.
  - `:106-118` toolchain pins (elixir 1.20.2-otp-28, OTP 28.5.0.2) — independently verified current.

### Test coverage

- No behavioral test of the task. Only refusal-renderer coverage:
  `test/mix/tasks/xaas_refusal_render_test.exs:48-54` asserts the
  `REFUSED(release_audit, ...)` line format with a hardcoded `"26.8.21"` fixture
  string (cosmetic only; does not exercise `run/1`).

## Fix sketch (v26.10.7 candidate / coordinator one-liner)

Minimal (one-liner class): change `lib/mix/tasks/xaas.release_audit.ex:14` to
`@version "26.10.6"`. That unblocks `check_version/1` (VERSION + mix version both
read 26.10.6 at HEAD). Remaining risk: the frozen `@resource_counts`/`70` total
and `docs/PRD-v26.8.21.md` existence check — verify counts still hold before
claiming green; if the domain census changed since 26.8.21 the audit will refuse
on counts, which is correct behavior.

Robust (small, preferred): replace the literal with
`@version File.read!("VERSION") |> String.trim()` (mirroring `mix.exs:13`), so the
audit baseline is version-variable and never goes stale on a VERSION bump again;
add a regression test running `run/1` against a real checkout asserting the
ALIVE line, per Chicago discipline (real collaborators, no mocks).

Not done here (contract: read-only lane; no edits).
