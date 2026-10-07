# W615 — wasm4pm + zcode-cli AIRo risk descriptions

Lane W615, AIRo wiring wave, v26.10.6. Date: 2026-10-06. Repos: `/Users/sac/wasm4pm`,
`/Users/sac/zcode-cli` (ONE canonical checkout each; nothing committed — coordinator
owns git). Pattern mirrors W603 (gymact) / W604 (autofde-lab).

## Files written (only these)

- `/Users/sac/wasm4pm/tests/ontology/airo_risk_description.ttl`
- `/Users/sac/wasm4pm/tests/ontology/test_airo_risk_description.py`
- `/Users/sac/zcode-cli/ontology/airo_risk_description.ttl`
- `/Users/sac/zcode-cli/test/airo-risk-description.test.ts`
- this receipt (xaas-side)

## wasm4pm mapping

AISystem = the WASM process-mining engine (`https://wasm4pm.example/airo/wasm-process-mining-engine`).

- Risk `UnreceiptedBuild` ← source `Source_UnreceiptedDistribution`; control
  `Control_CIReceiptChain` (`.github/workflows/ci.yml`: EXPECTED_SHA HEAD
  verification, boundary gates, emits + uploads `artifacts/ci/receipt.json`
  with subject_sha / workflow_count / standing=ALIVE — real file inspected,
  lines 35-46 and 153-164).
- Risk `FloatBoundarySelection` ← source `Source_FloatEpsilonBoundary` (w94
  flake: `0.30000000000000004 <= 0.30`, fixed to `0.3 + 1e-9`); control
  `Control_VitestScalingGate` (25-test
  `packages/ml/src/__tests__/algorithm-selection-with-scaling.test.ts`, run
  by CI's TypeScript integration job via `pnpm test`).
- Risk `EcosystemToolchainSemanticsDrift` ← source
  `Source_EcosystemToolchainDrift` (w525d's real `Map.update/4` absent-key
  probes returning `%{k: 7}` on elixir 1.20.4-otp-29; plus the wasm ABI's own
  `rust-toolchain.toml` nightly-2026-04-15 pin); mitigated by both controls.
- Consequences → Impacts → Stakeholder; qualitative Likelihood/Severity
  individuals, disclosed self-assessed (W603/W604 idiom).

## zcode-cli mapping

AISystem = the CLI agent runtime (`https://zcode-cli.example/airo/cli-agent-runtime`).

- Risk `ToolchainDrift` ← source `Source_EnvVarOnlyGate`; control
  `Control_BunTestGate` (`test:unit` = `ZCODE_REQUIRE_TOOLCHAINS=1 bun test
  test/*.test.ts`, package.json:67; court tests in
  `test/workflow-toolchain-court-hardening.test.ts`).
- Risk `SilentSkip` ← source `Source_UntypedSkipChannel` (expert-strategy +
  typed-skip report stream: `test/expert-strategy-config.test.ts`,
  `test/release-workflows.test.ts` typed-reason/NOT_EVALUATED rendering).
- Risk `ContractDrift` ← source `Source_ByteIdentityLease`; control
  `Control_ContractShaPins` — w356 shas recomputed this session and asserted
  in the check: gall-work `55157758…5fc4`, xaas-remote-relay
  `76ff551c…3f89` (both byte-identical to the w356 receipt).

## Verification (real output)

wasm4pm: `python3 -m pytest tests/ontology/test_airo_risk_description.py -v`

```
tests/ontology/test_airo_risk_description.py::test_cited_paths_exist PASSED
tests/ontology/test_airo_risk_description.py::test_ttl_exists_and_prefixes_declared PASSED
tests/ontology/test_airo_risk_description.py::test_rdflib_parse_and_airo_structure PASSED
tests/ontology/test_airo_risk_description.py::test_minimal_turtle_sanity_without_rdflib PASSED
4 passed in 0.23s   (Python 3.14.3, pytest 9.0.3, rdflib 7.6.0 — real parse, not skipped)
```

zcode-cli targeted: `bun test test/airo-risk-description.test.ts`

```
 4 pass
 0 fail
 21 expect() calls
Ran 4 tests across 1 file. [93.00ms]
```

zcode-cli full unit gate: `ZCODE_REQUIRE_TOOLCHAINS=1 bun test test/*.test.ts`

```
 1076 pass
 0 fail
 268380 expect() calls
Ran 1076 tests across 126 files. [98.19s]
```

(1076/126 vs w356's 1072/125: +4 = this lane's new check file; +21 expect()
calls; 0 fail either way — gate green with the new file included.)

## Standing

ALIVE on both checkouts — real pytest + bun runs, all cited paths witnessed on
disk, contract shas recomputed and pinned in-test. Nothing committed per lane
law.
