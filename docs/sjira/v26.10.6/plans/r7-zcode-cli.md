# R7 — zcode-cli fleet wiring plan (v26.10.5)

Lane: R7, read-only audit of `/Users/sac/zcode-cli`, branch
`fix/v26926-preview-publish-typed-skip` @ `7fc62da`, 18 dirty paths (13 modified, 5 untracked).

## 1. Standing (real evidence)

- **Branch/SHA**: `fix/v26926-preview-publish-typed-skip` @ `7fc62da` ("Merge remote-tracking
  branch 'origin/main' into fix/v26926-preview-publish-typed-skip"), on top of SA2A portable
  recovery closure (`60dc260`, `9025bb5`).
- **xaas coupling is real and two-way** (`docs/c4-zcode-cli-xaas.md`, dirty update in tree):
  1. Marketplace plugin: `~/.zcode/cli/plugins/cache/xaas-fabric-marketplace/xaas-fabric/26.9.17/`
     — installed from `~/xaas/priv/zcode_plugin/marketplace/` (ggen-rendered from `ontology.ttl`).
  2. `POST /execution/mcp` + `/execution/hooks/:event` + receipts endpoint in
     `~/xaas/lib/xaas_web/router.ex` (`/internal-api` scope, `RequireInternalApiToken`, fails closed).
  3. `zcode gall-work` native surface: `src/gall-work.ts` — claim→persist→construct→close.
  4. `xaas-remote-relay/1` worker-side admission: `src/relay-admission.ts`.
- **Contract sha parity verified this session (both byte-identical)**:
  - `test/fixtures/gall-work.contract.json` ≡ `~/xaas/priv/zcode_plugin/gall-work.contract.json`
    → sha256 `5515775…a95fc4`.
  - `test/fixtures/xaas-remote-relay.contract.json` ≡ `~/xaas/priv/ultracode/remote-relay.contract.json`
    → sha256 `76ff551c…3f89`.
- **Playwright**: zcode-cli ships `playwright-core@1.59.1` as a runtime dependency (browser-use
  surface, pinned by `scripts/check-runtime.ts` + `test/release-package.test.ts`). This is NOT a
  Playwright *test* surface; the fleet's Playwright validation surface lives in xaas
  (`@playwright/test ^1.62.1`, `playwright.config.cjs`, `test/bdd/next_read.spec.ts`).
- **Dirty 18 — all one coherent stream** (runtime-configurability + docs): `sync-runtime.ts`
  (+2 patches: `subagent-max-turns-env`, `expert-strategy-config`, both fail-closed with anchor +
  postcondition verify), `launcher.ts` (`--max-turns` lowering, `ZCODE_SUBAGENT_MAX_TURNS`),
  `src/max-turns.ts` (`resolveSubagentMaxTurnsEnv`, setting precedence env > setting.json > unset),
  matching tests (`max-turns.test.ts` extended, new `expert-strategy-config.test.ts` + 3 fixtures),
  doc updates (`CONFIGURATION*.md`, `HOST_INTEGRATION`, `RELEASING` incl. pkg-pr-new typed-skip
  outputs matching the branch name, `c4-zcode-cli-xaas.md` keyed-lease update), `AGENTS.md`/
  `HANDWRITTEN.md` inventory rows. Nothing in the dirty set touches gall-work, relay-admission,
  or the plugin render path — dirty set and fleet-coupling set are disjoint.
- **ash_surface coupling: none found.** No zcode references in `~/ash_surface/lib` or mix.exs.
  zcode-cli's only fleet coupling is to xaas (plugin + execution fabric + contracts).

## 2. Standing vocabulary

| item | standing |
|---|---|
| gall-work + relay contract parity (both repos) | ALIVE (sha-verified today) |
| xaas-fabric plugin install (26.9.17) | PARTIAL_ALIVE — pinned old version; xaas side has moved |
| xaas `/internal-api/execution` transport | PARTIAL_ALIVE (present in router; E2E via playwright not evidenced on this lane) |
| dirty v26.10.5 stream (max-turns/expert-strategy/typed-skip) | BUILD_BROKEN-unknown — committed nowhere, test run not executed (lane rule: no builds/tests) |
| ash_surface wiring | UNSUPPORTED(n/a) — no coupling exists or is required |

## 3. Gaps to "wired through xaas/ash_surface + Playwright-validated"

- **G1 Plugin version skew**: installed cache is 26.9.17; xaas `priv/zcode_plugin` has moved.
  Re-render + reinstall needed before any Playwright E2E run against current fabric.
  Gate: sha-verify `gall-work.contract.json` post-install (already matches at source).
- **G2 No E2E path for the CLI↔fabric loop**: no spec exercises
  `zcode gall-work` → `POST /execution/mcp` → sealed receipt. The fabric verbs are unit/
  contract-tested on both sides; the seam is not witnessed end-to-end under the fleet's
  Playwright validation bar.
- **G3 Dirty stream unlanded**: 18 files, includes tests + doc inventory updates that the
  v26.10.5 milestone expects (HANDWRITTEN says 25 patches registered). Until committed,
  every other lane's zcode assumptions read the pre-patch tree.
- **G4 Playwright config in xaas targets web surface only** (`playwright.config.cjs`,
  `test/bdd/next_read.spec.ts`); no zcode/fabric project wired into it.
- **G5** ash_surface: no work item — record UNSUPPORTED(n/a), do not invent coupling.

## 4. Proposed edits (exact, coordinator-owned execution)

Coordinator owns git; lane proposes only. **Note: zcode-cli is a lane-owned file set in the
lane map, so these are zcode-cli edits for the zcode lane writer, plus coordinator seam edits
in xaas.**

zcode-cli (lane-owned; on `fix/v26926-preview-publish-typed-skip`):
1. Commit the 18-file dirty stream as one coherent commit (it is one semantic change:
   runtime-configurability + docs + tests). No splitting; the tests and doc inventory rows
   travel together with the code they describe.
2. No further zcode-cli edits required for wiring — coupling is contract-pinned and already
   sha-verified. If the fan-out adds a fabric E2E, it adds a `test/e2e/*` fixture dir here
   only if the runner lives in zcode-cli; recommended runner lives in xaas (G2 below).

xaas (coordinator seams only):
3. `playwright.config.cjs`: add a `projects` entry (or reuse base) for the fabric E2E spec
   (G2), pointing `baseURL` at the local phx server with `INTERNAL_API_TOKEN` set from env.
4. New `test/fabric/zcode_cli_fabric.spec.ts` (new file, coordinator or X1 lane):
   - boots `mix phx.server` (test env, `INTERNAL_API_TOKEN` set),
   - runs `bun run /Users/sac/zcode-cli/bin/zcode.js gall-work --lease <tmp descriptor>`
     against a real leased worktree path,
   - asserts a sealed receipt appears via `GET /internal-api/execution/epochs/:id/receipts`
     and the keyed lease file exists at `<tmpdir>/xaas-fabric/*-<epoch>.json`,
   - negative court: assert typed refusal (`KNOWN_REPLAY` / gate deny) appears for a replayed
     command.
   Chicago-style: real server, real CLI subprocess, real Postgres — no mocks.
5. Bump/reinstall the xaas-fabric plugin cache (G1): re-render via the lawful generator
   (`ggen sync` from `~/xaas/priv/zcode_plugin/ggen.toml`), reinstall to
   `~/.zcode/cli/plugins/cache/xaas-fabric-marketplace/xaas-fabric/<new>/`, sha-verify both
   contracts in the installed copy.
6. Record the zcode-cli lane result in `_LANES.md`/frontier (X6).

ash_surface: **no edits** (G5).

## 5. Risks

- **R1 Runtime patch anchors are upstream-version-brittle**: `patchRuntimeSubagentMaxTurns`
  and `patchRuntimeExpertStrategyConfig` anchor regexes match the exact 3.14.3 bundle
  literals; the next upstream app bump can move them (the patch plan already types this as
  `BUILD_BROKEN(anchor moved)` — fail-closed is correct, but sync will refuse until re-anchored).
- **R2 Committed `package.json` version drift** (documented in dirty `RELEASING.md`):
  `<appVersion>-<n>` sync artifact can confuse version-pinning lanes (X4) — X4 should read
  `zcode-runtime.lock.json`'s `appVersion`, not `package.json`.
- **R3 Test run not executed** (lane rule: no builds/tests). The dirty stream's own tests
  (`max-turns.test.ts`, `expert-strategy-config.test.ts`) may be red; the fan-out should run
  `bun test test/max-turns.test.ts test/expert-strategy-config.test.ts` before committing.
- **R4 Contract drift risk is real, currently zero**: both contracts match byte-identically
  today; any xaas-side regen must re-run the sha check (zcode pins it in tests;
  `test/fixtures` sync test exists for gall-work).
- **R5 pkg-pr-new typed-skip doc claims** (`RELEASING.md` dirty text) describe workflow
  behavior not executed on this lane — verify against the actual workflow file before landing
  the doc claim (X5 CI lane).
- **R6 Plugin cache is a host-machine mutable** (`~/.zcode/cli/plugins/cache/…`) — the
  reinstall step 5 mutates host state outside any repo; get explicit operator consent before
  the coordinator executes it.

## 6. Falsifiers

- F1: `shasum -a 256` mismatch between `test/fixtures/gall-work.contract.json` and
  `~/xaas/priv/zcode_plugin/gall-work.contract.json` after any xaas regen → wiring invalid.
- F2: fabric E2E spec passes while `POST /execution/mcp` never received a request → spec is
  vacuous (assert on receipt read-back, not CLI exit code alone).
- F3: patch `verify:` postconditions pass but the anchor regex fails on the next upstream
  sync → proves R1; guard is already fail-closed.
- F2/F1 are the two run-able courts for this lane; run them at integration.
