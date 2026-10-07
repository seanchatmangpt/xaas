# W704 — zcode-cli → xaas gap wave receipt

Lane W704, 2026-10-06, xaas @ feat/playwright-surface.
Audit repo: /Users/sac/zcode-cli. Fill target: /Users/sac/xaas.

## Gap table

| zcode-cli pattern | xaas state found | verdict |
|---|---|---|
| (a) Toolchain court (`workflow-toolchain-court.ts` + `ZCODE_REQUIRE_TOOLCHAINS`): refuses any CI job that can reach a gated script without a verified ggen toolchain; adversarial mutants (H1–H11) | ci_cd.yaml parses `.tool-versions` via `scripts/versions.sh` + setup-beam `version-type: strict`, but NO in-repo test asserted the pins themselves or that the versions.sh extraction over the real file yields the CI build-arg versions | FILLED: `test/xaas/toolchain_court_test.exs` (4 tests) |
| (b) Contract-sha byte-exact pins — gall-work | ALREADY PRESENT: `test/xaas/zcode_plugin/gall_work_contract_test.exs` pins sha256 `55157758…` over `priv/zcode_plugin/gall-work.contract.json`; fixture byte-identical to zcode-cli's (verified by shasum this session) | TYPED-ALREADY |
| (b) Contract-sha byte-exact pins — xaas-remote-relay | GAP: fixtures byte-identical in both repos (sha256 `76ff551c…`, verified by shasum both sides), but `test/xaas/ultracode/remote_relay_test.exs` asserted only STRUCTURE, never bytes — any contract_version-1 mutation keeping the parsed shape passes = cross-repo drift channel | FILLED: `test/xaas/ultracode/remote_relay_contract_sha_test.exs` (3 tests incl. cross-repo byte-identity vs `../zcode-cli` fixture, typed skip when sibling checkout absent) |
| (c) Expert-strategy typed-skip stream (NOT_EVALUATED discipline) | Sweep of all `@tag skip` in test/: every skip carries a string reason (env-conditional or attribute-backed, e.g. `@compile_prose_skip`); zero bare `@tag :skip` | TYPED-ALREADY |

## Diffs (files written)

- `test/xaas/ultracode/remote_relay_contract_sha_test.exs` (new) — sha256 pin
  `76ff551c16cea5afb40b385ecee9ab7462ce1d73bee47655c0e0c63dc0a33f89` over
  `priv/ultracode/remote-relay.contract.json`; cross-repo byte-identity vs
  zcode-cli's `test/fixtures/xaas-remote-relay.contract.json` (typed skip
  when the sibling checkout is absent); contract identity check.
- `test/xaas/toolchain_court_test.exs` (new) — `.tool-versions` pins
  (`elixir 1.20.2-otp-28`, `erlang 28.5.0.2`, the documented/CI pins);
  versions.sh extraction logic (grep/cut semantics) replicated and asserted
  over the real file → `1.20.2` / `28.5.0.2`; ci_cd.yaml wired to
  `./scripts/versions.sh` + `version-type: strict`; versions.sh emits both
  versions into `$GITHUB_ENV`.

## Commands / exits

- `shasum -a 256` both fixtures: gall-work `55157758…fc4` identical in both
  repos; remote-relay `76ff551c…f89` identical in both repos.
- `MIX_ENV=test mix test test/xaas/toolchain_court_test.exs
  test/xaas/ultracode/remote_relay_contract_sha_test.exs`
  → `7 passed` (0 skipped; initial 1-skip was a fixture-path bug, fixed).
- Touched neighbors: `mix test test/xaas/ultracode/remote_relay_test.exs
  test/xaas/zcode_plugin/gall_work_contract_test.exs` → `16 passed`.

## Transport failures / notes

- Fresh lane build root `_build-laneW704` could not build: dependency
  `ash_a2a` fails to compile from scratch —
  `cannot build released AgentCard: :capability_release_closure_missing`
  (ash_a2a/chicago/bench/b11_wire.ex). Deterministic across two attempts
  (`deps.compile ash_a2a --force` included). PRE-EXISTING cross-repo dep
  issue, unrelated to this lane's diff. Tests were verified on the canonical
  `_build/test` root (MIX_ENV=test, pinned asdf toolchain) instead.
- Cleanup: `rm -rf _build-laneW704` was denied by session permissions; the
  orphaned lane build root (only 211 deps dirs, no app compile) remains on
  disk and needs coordinator deletion.

## Standing

- W704 lanes: contract-sha pin gap FILLED with real-hash courts; toolchain
  pin court FILLED; typed-skip discipline confirmed ALREADY ALIVE in xaas.
- Falsifier replay: delete `priv/ultracode/remote-relay.contract.json` or
  flip any byte → sha court fails; edit `.tool-versions` elixir line →
  toolchain court fails; revert either new test file → gap reopens.
