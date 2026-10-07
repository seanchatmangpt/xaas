# R3 — ggen_igniter audit: manufacture-profile state vs v26.10.5

Lane: R3 (ggen_igniter audit). Subject: `/Users/sac/ggen_igniter` @ `feat/adr-0010-gate-convention` @ `7dbcdb3a050ea4b2ce4d5f047ed2913052b5b539` (clean tree). Version in `mix.exs`: `26.10.5`.
Mission (_FRONTIER.md): "Manufacture profile (`ash-manufacture-pack`) present at the bound SHA; `mix ggen_igniter.sync --pack ash-manufacture-pack` executes."

Read-only audit; every citation below was observed this session on the exact subject.

## 1. Standing (real evidence)

| Item | Standing | Evidence |
|---|---|---|
| ggen_igniter 26.10.5 tree | compiles-ready, clean | `git log -1` → `7dbcdb3 feat(gate_verify): :engine opt with typed SPARQL_EXISTS_UNSUPPORTED refusal`; `git status -s` empty |
| ash-manufacture-pack exists | PARTIAL_ALIVE (fixture-only) | `priv/ggen/` contains **no** `ash-manufacture-pack`; the pack lives at `test/fixtures/ash_manufacture_pack/` (`ontology.ttl`, 13 `gates/*.rq`, `templates/manufacture.ex.eex`, `verify/*.unbound.rq`, `bin/{qualify,day_zero}.sh` + 5 python courts) |
| Hex consumers can reach the pack | UNSUPPORTED | `mix.exs` `shipped_packs/0`: `Path.wildcard("priv/ggen/*") |> Enum.reject(&String.contains?(&1, "ash"))` — every ash pack is excluded from the hex `files:` list; `lib/ggen_igniter/pack_catalog.ex:99-104` mirrors the same rule. `test/` is not in hex `files:`, so the fixture pack is unreachable from any hex install |
| xaas consumption edge | PARTIAL_ALIVE (hex, old) | `/Users/sac/xaas/mix.exs:226` `{:ggen_igniter, "~> 26.10.1"}`; `mix.lock` pins hex `26.10.1` |
| ash_surface consumption edge | UNSUPPORTED (no dep) | `grep ggen /Users/sac/ash_surface/mix.exs /Users/sac/ash_surface/mix.lock` → zero hits |
| Consumer-local pack precedent | ALIVE | `/Users/sac/xaas/lib/mix/tasks/xaas.library.manufacture.ex:3` header documents `mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack` (consumer-local pack dir, rendered in-consumer) |
| Cross-repo actuation guard | ALIVE | `.ggen_igniter/receipts/2026-09-09.jsonl` `rcpt_216c523b9b62a59f`: `GUARD_REFUSED {:refused_path_escapes_root, "/Users/sac/xaas/lib/xaas_web/mcp_scope.ex"}` — writes outside the running project root are refused by design |
| Fixture qualification evidence | ALIVE (fixture-scoped) | `test/fixtures/.qualification/book_library/` (commands.log, court logs). Pack README: standings are scoped to ash 3.33.1 / ash_postgres 2.13.1 / igniter 0.8.4 — "a different version set can move a task between ALIVE, PARTIAL_ALIVE and BUILD_BROKEN" |

**Doctrine drift**: the composition catalog (row D) and xaas doctrine name `ggen_igniter:priv/ggen/ash-manufacture-pack`. On the bound SHA that path does not exist — the pack is at `test/fixtures/ash_manufacture_pack`. Real location drift, not a misread.

## 2. Gaps to milestone acceptance

- **G1 — pack location.** `priv/ggen/ash-manufacture-pack` does not exist, so `--pack ash-manufacture-pack` cannot resolve by name (`GgenIgniter.Pack` resolves `priv/ggen/<name>` cwd-first, then the shipped dir under `deps/ggen_igniter`).
- **G2 — hex shipping rule.** `shipped_packs/0` blanket-rejects any path containing `"ash"`; even a promoted pack would not ship to hex consumers.
- **G3 — no 26.10.5 release edge.** xaas locks hex 26.10.1; ash_surface has no dep. No consumer can reach 26.10.5 until it is published (or overridden by a path dep).
- **G4 — ash_surface has no ggen_igniter dep.** No wiring edge exists there at all.
- **G5 — consumer ontology instances.** The pack's `amp:Project` block is book_library-specific; consumers need their own instances (otpApp, rootModule, task names). Consumer-side edit — coordinator/R1 handoff, not R3's files.
- **G6 — verify_mutation source path (latent).** `lib/ggen_igniter/verify_mutation.ex:99` `@source_pack Path.join(__DIR__, "../../test/fixtures/ash_manufacture_pack")` — `test/` is not shipped to hex. Latent while the pack stays a fixture (the path resolves inside this repo); goes live the moment G1's promotion happens without a matching path fix.

## 3. Exact proposed edits (ggen_igniter — R3's lane-owned files)

- **E1. Promote the pack**: `git mv test/fixtures/ash_manufacture_pack priv/ggen/ash-manufacture-pack`. Update the 8 test files that reference the fixture path (grep-verified list: `test/ggen_igniter_gate_verify_test.exs`, `test/ggen_igniter_verify_mutation_test.exs`, `test/ggen_igniter_ash_manufacture_pack_test.exs`, `test/ggen_igniter_ash_task_coverage_test.exs`, `test/ggen_igniter_agent_guard_test.exs`, `test/ggen_igniter_ash_gen_core_alignment_test.exs`, `test/support/postgres_case.ex`, `test/mix/tasks/ggen_igniter_verify_task_test.exs`).
- **E2. Fix the shipping rule** in `mix.exs` `shipped_packs/0`: replace the blanket `"ash"` substring reject with a named denylist that still excludes `ash-lifecycle-pack-inprocess-dispatch-test` but ships `ash-manufacture-pack`. Mirror the identical rule in `lib/ggen_igniter/pack_catalog.ex` (`shipped?/2`, ~lines 99-104, plus its comment).
- **E3. Ship-scope decision** (coordinator): ship the pack whole, or ontology/gates/templates/verify only (leaving `bin/` + `.qualification` evidence in-repo) to keep the hex package lean. Either way the shipped layout must keep `Pack.discover_queries/1` and the frontmatter `to:` convention working.
- **E4. Fix `@source_pack`** in `lib/ggen_igniter/verify_mutation.ex:99` to resolve the promoted `priv/ggen/ash-manufacture-pack` (keep a test/fixtures fallback only if a fixture subject remains in-tree).
- **E5. Doc sync**: update pack README path references, `docs/status.md` rows, and CHANGELOG for the new canonical location.

Commit split (fits ≤12-file default): commit 1 = E1+E2 (promotion + shipping, ~10 files); commit 2 = E4+E5.

## 4. Consumer-side edits (NOT R3's lane files — coordinator/R1 handoff)

- **C1. xaas** `mix.exs:226`: `~> 26.10.1` → `~> 26.10.5` after E1-E5 land and hex 26.10.5 is published (or a temporary path dep on `~/ggen_igniter` for the milestone).
- **C2. ash_surface** `mix.exs`: add `{:ggen_igniter, "~> 26.10.5"}` (or the same temporary path dep).
- **C3. Manufacture run shape**: run from inside the consumer repo — `mix ggen_igniter.sync --pack ash-manufacture-pack` (resolves the shipped pack under `deps/ggen_igniter`), or `--pack-dir priv/packs/<consumer>-ash-manufacture-pack` following the `xaas.library.manufacture.ex` precedent. Never drive writes from the ggen_igniter checkout: the path-escape guard (`rcpt_216c523b9b62a59f`) refuses out-of-root targets.
- **C4. Re-qualification**: run the pack's `bin/qualify.sh` against each consumer's resolved dependency versions before trusting the capability envelope there (see R-3).

## 5. Playwright scope (frontier rung 4)

ggen_igniter is a CLI/library repo with no UI surface. Per `_FRONTIER.md`'s rung-4 rule ("Repos with no UI surface … terminate at rung 3 with a receipt stating why"), R3 terminates at the wiring check. The Playwright-validated surfaces are the xaas marketplace-catalog and witness surfaces plus any ash_surface-generated surface wired into xaas — validated by the integration root's E2E run, not by R3.

## 6. Falsifier (milestone acceptance for this repo)

```
cd /Users/sac/xaas   # or ~/ash_surface
PATH=$HOME/.asdf/shims:$PATH mix ggen_igniter.sync --pack ash-manufacture-pack --out lib/mix/tasks/xaas.manufacture.ex
mix compile && mix test   # manufactured task executes a real ash.gen.* chain
```

- Pass: pack resolves by name from shipped hex 26.10.5, renders the orchestrator, consumer compiles+tests green → standing ALIVE.
- Fail modes: pack not shipped → `REFUSED(PACK_NOT_SHIPPED)`; no 26.10.5 release edge → `BLOCKED(RELEASE_MISSING)`; consumer dep versions outside the qualified envelope → `PARTIAL_ALIVE` with re-qualification required.

## 7. Risks

- **R-1. Diff breadth.** E1 alone touches ~9 files; with E2/E4 it exceeds 12 — hence the two-commit split above.
- **R-2. Consumer-side verify breakage.** If E4 is skipped while G1 lands, consumer-side `mix ggen_igniter.verify` file-not-founds at first use. High-probability latent break; cheap to fix now.
- **R-3. Envelope transfer.** The pack is qualified only at ash 3.33.1; xaas runs a different ash 3.x. Standing does not transfer automatically — re-qualify or disclose PARTIAL_ALIVE.
- **R-4. Chesterton fence.** The blanket `"ash"` reject in `shipped_packs/0` was added deliberately (hex size / fixture exclusion). The repair pass must `git log -S 'contains?(&1, "ash")'` to recover the reason before moving it.
- **R-5. Ship-scope** (E3) is a doctrine-level call (package size vs consumer completeness) — coordinator decision.
