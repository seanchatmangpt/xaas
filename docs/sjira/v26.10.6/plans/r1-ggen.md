# R1 — ggen fleet-convergence audit (v26.10.6)

Lane: R1 · Repo: `/Users/sac/ggen` @ `feat/v26.10.5-release-cut` @ `000bffb8f`.
Read-only audit; the only write is this plan file. No builds, no git mutations.
Companion lanes: R2 (ggen-marketplace), X1 (Playwright inventory), X2 (ash_surface), X3 (xaas web), X4 (version pins).

## 0. Lane history

Prior agent run died before writing; no partial plan file existed on disk (verified:
`docs/sjira/v26.10.5/plans/r1-ggen.md` not found; `docs/sjira/v26.10.6/plans/` was empty).
All evidence below is fresh, gathered this session via read-only commands on the exact subject.

## 1. Standing (real commands, run this pass, 2026-10-06)

| check | command | output |
|---|---|---|
| Tip | `git log --oneline post-release closure` | `000bffb8f chore(hygiene): untrack runtime OCEL telemetry — CA1 closure` |
| Working tree | `git status --short` | clean (0 entries) |
| Version | `grep -m1 '^version' Cargo.toml` | `26.10.5` (workspace.package) |
| Tag delta | `git rev-parse v26.10.5` = `b656d624d`; `git merge-base --is-ancestor v26.10.5 HEAD` = true | tag exists and is ancestor; tip is exactly **2 commits past the tag** — `8ac246add` (MU3 bounded replay-idempotency mutation sample: 0 survivors of 6 tested / 243 total) and `000bffb8f` (CA1 hygiene: untrack runtime OCEL telemetry) |
| Changelog | `git grep 26.10.6 -- Cargo.toml docs/CHANGELOG.md` | 0 hits — no v26.10.6 preparation anywhere in the tree; `docs/CHANGELOG.md` newest section is `[26.7.2]`, so the keep-a-changelog file is stale below the 26.10.x line |
| Browser validation | `git grep -l playwright -- '*.rs' '*.toml'` | 0 hits — ggen ships no Playwright harness of its own; browser-level fleet validation is delegated to consumer repos (§3) |
| Rust e2e | `ls tests/e2e` | `e2e_v510.rs`, `fixtures/`, validation reports (process-level e2e, not browser) |
| A2A/MCP surface | `ls crates/ggen-lsp/src/a2a_mcp` | `a2a/`, `a2a_generated/`, `a2a_registry/`, `mcp_packs.rs`, `mcp_server.rs` — ggen exposes A2A + MCP adapters over the sync pipeline (wired at `a66e61cdd`: "wire ggen.construct A2A adapter to the real sync pipeline") |
| CI hygiene | recent commits | `f9b0e6fa7 fix(ci): pin third-party actions + add job timeouts (ci-hygiene F2)` already landed |

## 2. Mission mapping — fleet wired through ~/xaas & ~/ash_surface, Playwright-validated, converged at v26.10.6

ggen's fleet edges observed on real subjects this pass:

1. **xaas → ggen (HTTP workbench surface).** `lib/xaas_web/router.ex:217–222` mounts
   `POST /api/workbench/ggen` + `GET /api/workbench/ggen/health` behind
   `XaasWeb.GgenWorkbenchController`, which delegates to `Xaas.Workbench.GgenClient`
   (`lib/xaas/workbench/ggen_client.ex`). The client is a bounded CONSTRUCT-only fence:
   argv ≤64 args / ≤512 B each, ≤256 files / ≤1 MiB each / ≤5 MiB total, timeout ≤300 s,
   forwards to a digest-pinned remote ggen capsule at `/v1/ggen/run`, worker re-admits
   independently, no shell. Unit coverage exists (`test/xaas/workbench/ggen_client_test.exs`)
   but **zero Playwright coverage** (X1 gap table confirms: `/api/workbench/ggen/*` —
   "the ggen workbench surface has zero coverage").
2. **xaas/ash_surface → ggen (pack channel).** Consumer repos do not consume the ggen
   repo directly; they consume locked marketplace packs (xaas castle-bridge @ `518572b6`,
   ash_surface ash-extension @ `baa5f117`) rendered by ggen's engine. The ggen-side edge
   is therefore indirect: ggen quality flows into the fleet through the marketplace pack
   channel and the workbench capsule.
3. **ggen-lsp A2A/MCP adapters.** `crates/ggen-lsp/src/a2a_mcp/` exposes ggen.construct
   over A2A and MCP — the machine-consumption edge for the fleet; no xaas/ash_surface
   consumer of it exists yet (xaas consumes ggen via the workbench HTTP fence instead).
4. **Playwright validation locus.** ggen itself has none; the mission's
   "Playwright-validated" clause lands on the xaas side (`/api/workbench/ggen/*`) and on
   the catalog read surface (`/marketplace-catalog`, PW3, already landed at xaas
   `d24d48a1`).

## 3. Gaps to mission (convergence at v26.10.6, closure only, no new features)

1. **Version convergence bump missing.** `Cargo.toml` says 26.10.5, tag `v26.10.5`
   sits 2 commits behind tip, no 26.10.6 string exists in-tree.
2. **ggen workbench surface has zero Playwright coverage.** The one fleet-visible ggen
   HTTP surface (xaas `/api/workbench/ggen/*`) is unit-tested only; X1's gap table
   already names it. This is the exact "ggen surfaces Playwright-validated" hole.
3. **CHANGELOG staleness is a release-cut closure debt.** Newest section `[26.7.2]`;
   26.10.x history exists only in release notes. A v26.10.6 release cut with this
   changelog would violate ggen's own keep-a-changelog discipline.
4. **Tag/branch state is release-ready but unconsumed.** The 2 post-tag commits are
   closure-class (mutation sample + hygiene), consistent with "closure only" — but the
   v26.10.6 cut hasn't happened, so downstream pins (R2's frozen-court ggen pin
   `v26.8.11` @ `402cecdf`, blocked on release artifacts) remain un-advanced.

## 4. Exact proposed edits (closure-only)

**E1 — v26.10.6 version bump in ggen (ggen side, closure).**
- `Cargo.toml`: `version = "26.10.5"` → `"26.10.6"` (workspace.package; all workspace
  crates inherit).
- Check for literal version strings in `crates/*/Cargo.toml` (they use
  `version.workspace = true` — expected zero per-crate bumps).
- `docs/CHANGELOG.md`: add a `[26.10.6]` section at top summarizing `8ac246add` and
  `000bffb8f` (and the 26.10.5 section, back-filled or referenced to release notes).
- Falsifier: `git grep 26.10.5 Cargo.toml` → 0 hits after bump; `cargo metadata` version
  coherence check green; `git grep -c 26.10.6 docs/CHANGELOG.md` ≥ 1.

**E2 — v26.10.6 release cut.**
- Tag `v26.10.6` on the bump commit after CI green (mirrors the `v26.10.5` cut).
- Unblocks R2's pre-staged ggen-pin-bump (`docs/context/ggen-pin-bump.pending.md`,
  currently BLOCKED:release-artifacts).
- Falsifier: tag exists at the bump commit; R2 can advance the marketplace's frozen
  ggen court identity.

**E3 — Playwright court for the ggen workbench surface (xaas side, coordinator-owned seam).**
- New file `/Users/sac/xaas/e2e/ggen-workbench.spec.ts` (X1 already reserves this gap):
  - (a) unauthenticated `POST /api/workbench/ggen` → 401 (auth floor court);
  - (b) authenticated with oversized argv / file bundle → 422 with
    `standing: "REFUSED[...]"` body (admission fence court, asserts the exact refusal
    vocabulary in `ggen_client.ex`);
  - (c) `GET /api/workbench/ggen/health` with bearer → 200/503 distinction: 503 body
    carries `standing: "REFUSED[WORKBENCH_NOT_CONFIGURED]"` when the worker is not
    configured — the court asserts the typed standing, not worker liveness, so it passes
    without the Fly worker running;
  - (d) optionally, `validate_payload/1` shape court via the `/rpc/validate`-style
    contract if the workbench exposes one; otherwise skip — do not require the remote
    capsule in CI.
- Env needed: `INTERNAL_API_TOKEN`. No remote worker dependency by design (court (c)
  asserts the typed refusal, keeping the spec hermetic).
- Falsifier: spec green against `mix phx.server` on :4000; removing the auth plug or the
  refusal mapping makes courts (a)/(b) fail.

**E4 — CHANGELOG back-fill (folded into E1).** One `[26.10.6]` section; do not attempt a
full 26.7.3→26.10.5 back-fill in this cycle (out of closure scope; record as standing debt).

## 5. Risks

1. **E3 depends on xaas-side coordinator lane (X3/X1), not ggen.** The ggen repo cannot
   satisfy the Playwright clause alone; if the xaas lane doesn't land the spec, ggen's
   convergence claim stays partial. Mitigation: E3 is a single new file with no
   application-code change; cheap for the coordinator to absorb.
2. **Court (c) could false-pass if the workbench is configured but unhealthy.** The
   court asserts typed standing, not health; an actual `200` also passes (assert
   `status in [200, 503]` AND correct standing vocabulary — precise assertion written
   into E3(c)).
3. **Tag cut (E2) requires CI green on the bump commit.** Bumping workspace version can
   break version-pinned tests (fixture receipts embedding version strings). Mitigation:
   `git grep 26.10.5 -- tests crates` before cutting; fix-forward any fixture that pins
   the literal.
4. **CHANGELOG scope creep** — back-filling 26.8–26.10 is explicitly out of scope (E4).
5. **No-builds constraint this pass** — E1/E2 falsifiers requiring cargo runs are
   deferred to the implementer pass; this audit claims only read-only standing.

## 6. Standing summary

| item | standing |
|---|---|
| ggen repo @ 000bffb8f, tree clean, closure commits landed (MU3, CA1) | ALIVE |
| v26.10.6 version bump + changelog + tag (E1/E2) | UNKNOWN (edits proposed, not executed) |
| ggen workbench Playwright court (E3, xaas side) | UNKNOWN (gap confirmed by X1; spec proposed) |
| ggen-lsp A2A/MCP adapters over sync pipeline | PARTIAL_ALIVE (wired + unit-level; no fleet consumer) |
| marketplace ggen pin bump (R2 dependency) | BLOCKED:release-artifacts (until E2) |
