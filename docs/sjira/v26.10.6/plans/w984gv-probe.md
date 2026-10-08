# W984gv — unclaimed-family probe: release/versioning surface (release_audit)

- Lane: W984gv, canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface` (unchanged, no commit)
- Subject SHA at receipt: `git rev-parse HEAD` at time of writing: `16a7bfa5` (16a7bfa5d... batch #5 receipt commit)
- Date: 2026-10-07

## Scope

Release/versioning family: `lib/mix/tasks/xaas.release_audit.ex` (the tool remediated
earlier this campaign, 19→0 findings), VERSION/CHANGELOG consistency surface, plus the
two campaign-remediated bugs (Version.parse "v"-prefix rejection; inverted `max_by`).

## Census (pre-probe)

- `lib/mix/tasks/xaas.release_audit.ex` — the audit task (sole release-audit tool).
- Existing tests:
  - `test/mix/tasks/xaas_release_audit_test.exs` (13 tests): W612 tag legs, W872 required
    inputs, stale-pin parity. Covers tag fixtures via real git repos.
  - `test/xaas/release_audit_enoent_court_test.exs` (4 tests): W845/W872 typed-absent
    contract, determinism.
- Gap found: the W650k remediated `newest_release_tag/0` fixes (v-prefix strip + max_by
  comparator) were pinned only by a literal `Version.compare` assert on unparsed strings —
  no test drove `newest_release_tag/0` over a real multi-tag repo, so both remediated
  bugs could regress with every existing test green.

## New court

`test/xaas/release_audit/family_court_w984gv_test.exs` — 6 tests, zero mocks, real git
fixture repos / real temp trees, per-test mutation rationale:

1. **W650k regression pin (both remediated bugs)**: real 3-tag repo {v1.0.0, v26.9.29,
   v26.10.6}; asserts `newest_release_tag/0 == "v26.10.6"`. Kills (a) reintroduced
   v-prefix parse rejection (collapses to lex-first listing → v1.0.0) and (b) lexicographic
   max_by (→ v26.9.29). The pre-existing literal comparator pin passes under both mutants.
2. Non-`vX.Y.Z` tag filter (v1.0.0 vs `v26` vs `rel-26.99` → v1.0.0).
3. `newest_release_tag/0` typed transport-failure arm `{:error, reason}` (non-git cwd) —
   previously unexercised.
4. `render_refusal/1` exact `REFUSED(code, detail: %{...})` shape (previously unexercised).
5. Glob-expansion branch of `unresolved_plan_refs/2`: resolving class-glob reference emits
   no finding; non-resolving class-glob still flags (anti-vacuity).
6. `closure_receipt_findings/1` fail-closed arms: missing closure plan; empty receipt
   corpus — real temp trees, typed findings asserted.

## New product finding + remediation (in-scope, minimal)

Probing leg 5 exposed a **real latent bug** in `unresolved_plan_refs/2`
(lib/mix/tasks/xaas.release_audit.ex): `Path.wildcard/1` does not expand `[...]`
character classes, and on this OTP (28.5.0.2) `:filelib.wildcard/1` also fails when a
literal `-` immediately follows a `[...]` class (`w[0-9]-first.md` → `[]` while
`w?-receipt.md` matches). Any closure-plan glob reference of the form
`docs/sjira/vX/plans/w[0-9]-receipt.md` always read as unresolved → false-positive
typed finding on an otherwise green audit. Empirical probes (real elixir runs):

- `Path.wildcard(".../w[0-9]-receipt.md")` → `[]` (Elixir globs support only `?`, `*`, `**`)
- `:filelib.wildcard('...w[0-9]-receipt.md')` → `[]` (dash-after-class OTP quirk)
- `w?-receipt.md`, `w[0-9]*` → match

Fix: `ref_resolves?/1` widens each `[...]` class to `?` before `Path.wildcard/1`
(conservative over-accept within same filename shape; never under-accept). Anti-vacuity
held: `w[0-9]-MISSING.md` still flags.

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gv mix test
  test/xaas/release_audit/family_court_w984gv_test.exs test/mix/tasks/xaas_release_audit_test.exs
  test/xaas/release_audit_enoent_court_test.exs` → **23 tests, 0 failures, exit 0**
  (all 6 new court tests pass; 17 pre-existing release_audit tests unbroken).
- Mock gate: `mix run -e 'IO.inspect(...scan_mock_usage(["test", "lib"]))'` → `[]`.

## Standing

ALIVE for the court + the one-line family fix. No commit (lane discipline); changes left
in working tree: `lib/mix/tasks/xaas.release_audit.ex`,
`test/xaas/release_audit/family_court_w984gv_test.exs`, this receipt.
