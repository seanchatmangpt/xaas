# W984dy — Probe Receipt: Repo-Adapter Chicago Courts (ILSRepo FixtureAdapter + AwsRepo adapters)

- **Lane**: W984dy, canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface` (unchanged).
- **Subject**: `Xaas.Library.ILSRepo.FixtureAdapter` (W984du 5th re-census residue #1, 4 pubs),
  `Xaas.AwsRepo.FixtureAdapter` (2 pubs), facade/config surface of `Xaas.AwsRepo` /
  `Xaas.Library.ILSRepo`. `Xaas.AwsRepo.AwsAdapter` (2 pubs) partially covered — see
  "Disclosed-uncovered" below.
- **Files created (handwritten tests only, zero lib/ changes)**:
  - `test/xaas/library/ils_repo_fixture_adapter_deepening_test.exs` — 13 tests: all 4 pubs,
    hit + miss branches (`:patron_not_found`, `:item_not_found`, unknown-student `{:ok, []}`),
    fixture data edge cases (availability flags, grade-level frequencies, item_information ↔
    get_catalog agreement), facade dispatch through configured default adapter.
  - `test/xaas/aws_repo_adapters/aws_repo_adapters_deepening_test.exs` — 7 tests:
    FixtureAdapter both pubs (float-in-range with fixture jitter, instance-id
    agnosticism, exact fixed instance id `i-09ba9852c02d92e38`), facade dispatch, configured
    adapter shape via `Application.fetch_env!(:xaas, Xaas.AwsRepo)` (adapter_module/0 does not
    exist publicly; corrected to config read).
- **Verification (real output)**:
  - `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dy mix test
    test/xaas/library/ils_repo_fixture_adapter_deepening_test.exs
    test/xaas/aws_repo_adapters/aws_repo_adapters_deepening_test.exs`
    → `Result: 20 passed` (13 ILSTest + 7 AwsTest), exit code 0. Fresh
    `_build-laneW984dy` compiled from scratch (~25 min) — clean.
    Compiler emitted only cosmetic type warnings on `assert is_float/1` (test-side, non-fatal).
  - Mock gate: `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'`
    → `[]` (expect `[]`). PASS.
- **Testing discipline**: Chicago. Real fixture data, real config reads, real facade dispatch.
  No mocks, no stubs, no interaction assertions. FixtureAdapter hand-written real interface
  implementations are court subjects, not mocks.
- **Disclosed-uncovered**: `Xaas.AwsRepo.AwsAdapter.get_cpu_average/1` and
  `get_self_instance_id/0` make live network calls (CloudWatch via ExAws; EC2 IMDS at
  169.254.169.254) with no injection seam. No real collaborator is reachable in this
  environment (same register as SIP2Adapter's PARTIAL_ALIVE: no live vendor endpoint), so
  those two pubs remain uncovered rather than mocked. `config/runtime.exs:33` points
  AwsAdapter at `http://localhost:1338`, an untested seam.
- **Standing**: ALIVE for the 20 courts on the exact subject files above; UNSUPPORTED
  (no-live-collaborator) for AwsAdapter's two live-network pubs.
- **Lane hygiene**: `rm -rf _build-laneW984dy` attempted post-verification — **DENIED by
  permission system**; the directory remains on disk as a lane lease for the coordinator to
  clean at integration.
- **NO commit made.** Coordinator owns integration.
