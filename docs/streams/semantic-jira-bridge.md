# Semantic Jira Bridge: Stream Notes

v26.9.20. Stream `xaas-semantic-jira-bridge`, branch `errc/semantic-jira-bridge`, base
`e37b9f9534978f36161ba21e62f84412b51c5f81` (xaas `main` at stream start). This note is for the
integrator: it carries the status rows and findings that would otherwise touch `docs/status.md`,
`CHANGELOG.md` and the `mix.exs` version, which this stream deliberately leaves alone.

`Xaas.Ultracode.SemanticJiraBridge` closes the loop between the canonical work graph
(`GgenIgniter.SemanticJira.*`, called in-process) and the Ultracode fabric, with typed
`{:error, {:refused_bridge, reason}}` refusals and `authority: NONE` throughout.

## Status rows

| Capability | Status | Evidence |
|---|---|---|
| Candidate admission (kernel + SHACL), `admit_candidate/2` | ALIVE | crown step 3 |
| Frontier over the log, `frontier/2` and `state/2` | ALIVE | crown steps 4, 11, 12 |
| Descriptor via `Descriptor.build/4` into `SemanticWork.admit/1` | ALIVE | crown steps 5-6 |
| Sealed receipt -> reconciler receipt, `reconciler_receipt/2` | ALIVE | crown steps 8-9 |
| Transition appended, new frontier returned, `admit/5` | ALIVE | crown step 9 |
| Refusals: tamper, unsealed, stale definition, unadmitted | ALIVE | pure suite, refusal tests |
| Kill producer, replay from a log copy: same state | ALIVE | crown steps 11-12 |
| Same replay in a fresh OS process (`mix run`) | ALIVE | `:subprocess` test |
| A2A task carries the descriptor identity, `a2a_task/3` | ALIVE | pure suite |
| Pack agent card agrees with descriptor and task state | ALIVE | pure suite |
| xaas-served ash_a2a agent card, semantic work | UNSUPPORTED(generator-capability) | none exists |
| `receipt_digest/1` swapped for `SemanticJira.digest/1` | REFUSED (not identical) | falsifier |
| `SemanticCrown` moved off `mix semantic_jira.*` tasks | BLOCKED | see findings |
| Observation edge (finding -> candidate over full pack) | BLOCKED | see findings |

## Dependency change

`mix.exs`: `{:ggen_igniter, "~> 26.9.12"}` became
`{:ggen_igniter, path: "/Users/sac/ggen_igniter-wt2/xaas-dep", override: true}`, a detached checkout
of ggen_igniter `dcebc422978498fefff90854a475b1001804f17a` (26.9.20 is unpublished). `mix deps.get`
resolved with no other change: no `ash_a2a`, `ash`, `plug`, `bandit` or `req` constraint had to
move, and `mix.lock` is untouched (its hex `ggen_igniter` entry is ignored while the path
dependency is in force). Revert to the published requirement once 26.9.20 is on Hex.

## Findings about ggen_igniter 26.9.20

The code the older xaas crown was written against is not in `dcebc42`:

- `Descriptor.receipt_from_xaas/2`, `SemanticJira.digest_exact/1`, `Reconciler.tail_digest/1` and
  `Reconciler.project/2` are absent; `Descriptor.build/4` now emits the
  `semantic-jira/execution-descriptor/v1` shape (`work_order_id`, `package`, digests), not the
  11-field `SemanticWork.admit/1` key set.
- The `mix semantic_jira.{observe,descriptor,xaas_receipt,reconcile,frontier}` tasks and
  `Observation.candidate/3` are absent. They live on `feat/semantic-jira-descriptor-bridge`
  (`92cd993`), an ancestor of `dcebc42` whose files are nonetheless absent there.
- `Reconciler.reconcile/4` now takes `definition_digest`, `snapshot_digest`, `target`,
  `candidate_sha`, `evidence` and digests the whole receipt itself.

Consequences here: the descriptor composition and receipt mapping are hand-written residue in the
bridge (`UNSUPPORTED(generator-capability)`: no ggen pack manufactures XaaS-side glue). Everything
else is a call into the kernel. `SemanticCrown` and its test (skipped on this machine) still target
the older task line and were left unchanged; the bridge is the in-process replacement for its
`descriptor`, `xaas_receipt`, `reconcile` and `frontier` steps. The `observe` step has no 26.9.20
counterpart, so the crown's observation edge stays BLOCKED until ggen restores it.

## Equivalence audit (why nothing was deleted)

`SemanticReceipt.receipt_digest/1` equals `GgenIgniter.SemanticJira.digest/1` byte for byte on
every export variant tried, and `SemanticJiraBridgeTest` proves it. It is not replaced because the
kernel digest silently drops seven reserved top-level keys (`work_order_digest`,
`transition_digest`, `evidence_digest`, `experience_digest`, `repair_digest`, `finding_digest`,
`composition_digest`): a foreign export carrying one verifies under the kernel digest and not
under the export digest. The same test exhibits that divergence for each key.
`SemanticWork.admit/1` has no kernel counterpart at 26.9.20 (different shape), so it also stays.

One export change was needed: `SemanticReceipt.export/1` previously exported a court receipt only
through a per-suite adapter, so a fabric-produced `CourtReceipt` (the one carrying `"binding"`)
never reached the digest for suites like these. It is now exported verbatim for any suite. Suites
without a produced court receipt export exactly what they did before.

## Falsifiers run

Mutants of the bridge, each killed by at least one test: credible-head gate forced true, frontier
gate off, digest check off, fabric re-check off, court witness forced true, ceiling taken from the
work order instead of the fabric ceiling.

## Standing ledger

- Evidence ceiling is `repository-local`: fabric-only evidence never reaches a higher ceiling, so a
  work order that demands more is refused with `promotion_refused [:ceiling]`.
- SHACL admission in the tests uses an inline subset of the pack shape (the pack's closed shape
  needs the whole ontology graph around an order), as ggen_igniter's own crown does.
- No push, no publish, no merge, no lease beyond the tests' own sandbox.

## See Also

- `lib/xaas/ultracode/semantic_jira_bridge.ex` for the contract and refusal vocabulary.
- `docs/ultracode/wave-v26.9.19-receipts/semantic-autonomics-crown/proof.md` for the subprocess-era
  crown this bridge supersedes in-process.
- ggen_igniter `lib/ggen_igniter/semantic_jira/{reconciler,transition_log,descriptor}.ex`.
