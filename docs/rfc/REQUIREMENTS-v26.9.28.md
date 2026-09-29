# v26.9.28 Requirements

Derived 2026-09-28 from evidence: `VERSION`=26.9.28 (`55a70dd`), the v26.9.28 runtime
branches (FOND control plane, provider fabric/mesh, execution federation, execution
closure r14, trimtab runtime), and the failures observed integrating them. Not a
production gate (see CLAUDE.md operating mode): each requirement states its evidence
and its status is reported as observed.

| ID | Requirement | Falsifier | Status |
|----|-------------|-----------|--------|
| REQ-1 | Integration line contains every lawful unmerged branch; each unmerged branch has a typed disposition | `git branch -r --no-merged HEAD` minus ledger below is empty | see ledger |
| REQ-2 | Every `.ex/.exs` in `lib/ test/ config/` parses under the pinned toolchain (elixir 1.20.2-otp-28) | `test/xaas/release/tree_parse_guard_test.exs` | implemented, passing |
| REQ-3 | Integrated tree compiles with no `undefined module/function` diagnostics | `mix compile --force` output grep | `mix compile` exit 0; undefined-ref warnings fixed; done |
| REQ-4 | Merge seams keep one source of truth: Ultracode consequence fence (`Lease.refused_consequence_tools/0` vs `RuntimeSurface`) | `test/xaas/pack/pack_ontology_test.exs` equality | attribute restored; pack test passes |
| REQ-5 | Competing add/add implementations of `Xaas.ResearchRuntime.*` are resolved to one (r14 formatted set) and no HEAD-only consumer breaks | compile + `test/xaas/research_runtime/**` | r14 set taken; `research_runtime` tests pass |
| REQ-6 | Version metadata consistent: `VERSION`, CHANGELOG entry | CHANGELOG has `[v26.9.28]` | done |
| REQ-7 | Generated one-line code is normalized by the formatter, not hand-edited | `mix format --check-formatted` on runtime dirs | DONE: `mix format` applied to files changed since 7c3dc68 (236 rewritten); suite unchanged 2489/2490 |
| REQ-8 | Multi-clause functions declaring defaults use a header; `mix compile --force --warnings-as-errors` clean for project code (CI gate `wd-cs2`) | CI compile court | DONE (5 warnings fixed; WaveLoop step-frontier `record_step_frontier` call restored) |

## Branch ledger (disposition of the 37 non-backup unmerged branches)

- MERGED clean (20): docs/session-update-2026-09-01, v23/V23-W, feat/v26.9.25-spg-brce-admission,
  feat/v26.9.25-remote-relay-reconcile, feat/2609-29345-sjira-governance-obligations,
  feat/frozen-release-snapshot-v26.9.26, verify/v26.9.25-substitution-evidence-binding,
  feat/v26.9.26-abb-sbb-rfc-seed, closure/cs2-pack-consumer-20260926-1640,
  expansion/v26.9.26/sjira-{engineer-workflow-r1,atlassian-delivery-r2,atlassian-transport-*},
  fix/v26.9.27-canonical-ggen-pack-routing, runtime/v26.9.27-provider-recovery-factory-1519,
  feat/v26.10.1-legacy-recovery-fabric, runtime/v26.9.28-{fond-provider-mesh-001,fond-control-plane-r2,provider-fabric-r3,execution-federation-r13,trimtab-runtime-r2},
  research/v26.9.27-self-digest-runtime.
- MERGED with `-X ours` / resolution (9): runtime/v26.9.28-execution-closure-r14 (theirs for add/add),
  claude/practical-hopper-3141gg, rela/xaas-sj001-digest-probe, closure/cs2-fleet-r4-xaas,
  closure/max-code-cs2-fleet-r5, swarm/closure-20260926-203726-r7, swarm/closure-20260927-0039-r13,
  r2/ci-preflight-295e020, feat/v26.9.27-ultracode-closure-controller.
  Caveat: HEAD-wins can drop branch-only hunks; branch-only intent is UNVERIFIED.
- UNSUPPORTED (unrelated histories, no merge base): ash-migration, feat/v26-9-12-substrate,
  feat/ep1-missed-epoch-receipt.
- DEFERRED (stale early-Sept, 4-107 file conflicts incl. mix.lock/Dockerfile/migrations, superseded by main):
  rename/kanban-to-xaas, feat/ash-ai-mcp-a2a-next-read, fix/coupling-engine-zero-weight,
  fix/ocel-import-typed-error.
- SKIPPED by design: `backup/*`.

## Observed verification (2026-09-28, pinned elixir 1.20.2-otp-28 installed from builds.hex.pm; postgres 16 + pgvector)

- `mix compile` exit 0. `mix test`: 2489/2490 passed (2483/2484 tests, 6/6 doctests; 105 skipped, 76 excluded by tags).
- OPEN failure: `Xaas.Ultracode.RecipeWorkerTest` "a lease lost between steps ..." expects
  `{:lease_lost, {:no_lease, redacted}}` with the redacted lease-token digest; the `DurableClose`
  fence (7e4d6a1) now returns `{:lease_lost, :no_lease}` with no token. Reconciling requires deciding
  whether the token-redaction assertion is retained (security-relevant) - deliberately NOT edited here.
- Test-side reconciliations made (behavior kept, stale expectations updated): A2A bridge -> `from_a2a/1`;
  Gall contract tool set/`result_fields`; VKG graphql first-row order; relay `acknowledge` fixed clock.
- Source fixes: Atlassian tuple digest + JSON-safe checkpoint outcomes; VKG `rows_by_contract` passthrough;
  release-snapshot codec `{:serialized_authority_widened, _}`; CapitalCensus resources -> `Xaas.Resource`
  (note: still no policy block - policy floor is a follow-up); DateTime comparators; `build_goal` text.
- Not run: `mix test --include stress`, mock grep, `mix format --check-formatted` gating.
