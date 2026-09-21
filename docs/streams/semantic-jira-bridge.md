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

`mix.exs`: `{:ggen_igniter, "~> 26.9.12"}` became a path dependency (26.9.20 is unpublished).
First round: `/Users/sac/ggen_igniter-wt2/xaas-dep`, a detached checkout of ggen_igniter
`dcebc422978498fefff90854a475b1001804f17a`. Repair round:
`/Users/sac/ggen_igniter-wt2/log-integrity`, branch `errc/xaas-bridge-log-integrity` at `203cecb`,
which is `dcebc42` plus ONE commit (`TransitionLog` `event_digest` commits to the receipt an event
cites; see "Repair round"). `mix deps.get` resolved with no other change: no `ash_a2a`, `ash`,
`plug`, `bandit` or `req` constraint had to move, and `mix.lock` is untouched (its hex
`ggen_igniter` entry is ignored while the path dependency is in force). Revert to the published
requirement once 26.9.20 is on Hex WITH that commit; the integrator must land `203cecb` in
ggen_igniter first (it does not touch `transition-store`'s `Store.event_digest/1` line, which
needs the same one-word change: `digest` to `digest_exact`).

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
through a per-suite adapter, so a fabric-produced `CourtReceipt` never reached the digest for
suites like these. It is now exported verbatim for any suite, but only when the export itself can
show the receipt was fabric-produced (repair round: the Run has a court map, and the receipt's
binding names that Run's suite, the sealed head and a step the verifier ran; a `"binding"` key
alone proved nothing, see finding 1). Suites without a produced court receipt export exactly what
they did before.

## Falsifiers run

Mutants of the bridge, each killed by at least one test: credible-head gate forced true, frontier
gate off, digest check off, fabric re-check off, court witness forced true, ceiling taken from the
work order instead of the fabric ceiling.

## Verification (2026-09-21)

Run in the stream worktree with `MIX_TEST_PARTITION=jb` (own database), machine load average
above 100 throughout.

| Check | Result |
|---|---|
| Bridge, bridge crown and receipt suites (three files) | 48 tests, 0 failures |
| Existing ultracode/semantic suites (receipt, work, wave, court, lease) | 139, 0 failed |
| `test/xaas/ultracode` (whole directory, `--include subprocess`) | 571 tests, 1 failure |
| xaas A2A agents, gall, zoe, frontier evidence under the path dependency | 76 tests, 0 failed |
| `mix format --check-formatted` on touched files | clean |
| `mix credo --strict` on touched files (scratch runner, xaas has no credo) | no issues |
| Mock grep over touched files | exit 1, no output |
| `mix compile --force --warnings-as-errors` on the branch | exit 1, pre-existing |
| Same gate on the branch merged with `main` (scratch worktree) | exit 0 |
| Narrow suites on the branch merged with `main` | 108 tests, 0 failures |

Pre-existing, not introduced here:

- The compile gate fails at the base only on `lib/xaas/castle.ex:572,839` and
  `lib/xaas/semantics/computation.ex:390`; `main` (`8e72cfc`, errc/xaas-closure) fixes them.
- `AutonomicMultiRepoTest` ("one wave works several repos end to end") returns `PARTIAL_ALIVE`,
  not `ALIVE`, identically at the base SHA with the hex `ggen_igniter` and no change of ours.
- `mix format --check-formatted` on `main` flags `test/xaas/semantics/registry_test.exs`.
- `SemanticCrownTest` is skipped by name (no operator APS clone, no `semantic_jira.*` tasks).

## Repair round (qualifier findings, 2026-09-21)

Six qualifier findings (five defects, one duplicated) were reproduced by the committed red tests
(`12021c0`, `e6114ce`: 13 red of 15) and each is now green with a permanent guard. Mutants of every
fix were run and each is killed by at least one test (details under "Mutants killed").

1. Forged court receipt, no court map. A worker-printed JSON line carrying a `"binding"` key was
   exported as a fabric court receipt and promoted un-fixed work to ALIVE. Root cause: `"binding"`
   was the trust marker in three places (`Verifier.maybe_put_receipt/3`,
   `Lease.publish_court_receipt/2`, `SemanticReceipt.observed/3`) and is worker-reachable through
   the legacy script-output path. Fix: `Verifier` drops a legacy line carrying `"binding"` and
   marks the result `legacy_court_receipt_refused`; `SemanticReceipt.export/1` exports a court
   receipt only for a Run with a court map, bound to that Run's suite, the sealed head and a step
   the verifier ran; the bridge credits a binding only for a passing step of the export. Guard:
   `SemanticJiraBridgeForgedCourtTest` (red before), the legacy cases of
   `VerifierVerdictSourceTest`.

2. Forged verdicts with a court map in force. A worker that fixes nothing and rewrites `check.sh`
   to echo the mapped `PASSED` lines was promoted (observed: with the pin disabled, un-fixed work
   is admitted as ALIVE). Root cause: verdicts are read from what a repo-resident script prints,
   and the worker writes the repo. Fix: the court pins the verdict sources to the base SHA. Every
   file a `pytest_v` test id names and every regular-file operand of the receipt step must be
   byte-identical from base to head, else the run is `"error"` with `{:verdict_source_modified,
   path}`. Git is read with `GIT_NO_REPLACE_OBJECTS` and `--no-renames --no-ext-diff`, because a
   `refs/replace` entry hides a rewrite from a plain `git diff --quiet`. Guard:
   `SemanticJiraBridgeProvenanceTest` (real Postgres, real `Lease.close/4`) and
   `VerifierVerdictSourceTest`.

3. Malformed but digest-valid exports raised. `reconciler_receipt/2` walked `fabric_verifier`,
   `steps` and the court receipt without checking their shape (Access, Enumerable and
   FunctionClause errors). Fix: `shape_ok/1` returns `{:malformed_export, path}`; a non-JSON
   export is `:export_not_json`; a non-string `epoch_id` is refused before any fabric lookup.
   Guard: the 7 red tests, now green, plus a wrong-typed value (6 types) at each of 32 export
   positions in `SemanticJiraBridgeIntegrityTest`.

4. Orphaned claim reported as an admission (findings 4 and 6). A writer killed after claiming an
   event digest left an orphan marker, and the next admit answered `{:ok, %{event: nil,
   disposition: :already_recorded}}` over an empty log. Root cause: `TransitionLog.await/3`
   returns `{:ok, nil, :already_recorded}` after 5 s and the bridge passed it through. Fix:
   `acknowledged/3` refuses `{:log_claim_orphaned, receipt_digest}`; `reap_orphaned_claims/1`
   (under the log lock) clears markers no event backs, after which the receipt lands. Guard: the
   falsifier and orphan-claim tests (red before) and `SemanticJiraBridgeIntegrityTest`.

5. `event_digest` did not commit to the receipt an event cites. A second, different receipt was
   answered `:already_recorded` with the first receipt's event (six OS processes: 1 appended, 5
   false acknowledgements), a swapped `receipt_digest` was invisible, and `ledger_tail` collided.
   Root cause: `SemanticJira.digest/1` drops `receipt_digest` and `transition_digest`, and
   `TransitionLog.append/2` derived `event_digest` with it. Fix, UPSTREAM in ggen_igniter
   `203cecb`: `SemanticJira.digest_exact/1` and `TransitionLog.event_digest/1`; the bridge
   verifies that the returned event cites the submitted receipt (`{:receipt_not_recorded, ...}`)
   and re-derives every event it reads. Guard: ggen_igniter `transition_log_digest_test` (7
   tests), the bridge falsifier test (red before), the `acknowledged/3` cases.

Two consequences of finding 5 that the qualifier did not name:

- Once the digest commits to the receipt, the accidental serialization that identical-transition
  events used to enjoy is gone: unserialized racers of DIFFERENT receipts would each append a second
  `UNKNOWN -> ALIVE`. Observed with the OS lock bypassed: six racers, six `ok:appended`. So the
  admission decision now runs under `Xaas.Ultracode.LogLock` (an `flock(2)` held by a `perl` helper,
  released by the kernel when its holder dies; `:global.trans` stays for in-node ordering).
  `SemanticJiraBridgeRaceTest` (`:subprocess`) races six real OS processes: one appends, five are
  refused `not_on_frontier`.
- The log became a trust root the bridge verifies on every read: each event re-derives its
  `event_digest` (current rule, or the legacy rule for old logs) and each work order's standing
  chain is unbroken. An event that fails leaves nothing eligible and nothing appendable
  (`{:log_untrusted, detail}`). The qualifier's hand-written ALIVE event with a bogus digest is
  covered (12th red test).

Residual, stated so it is not read as closed:

- A `mix_trace` suite maps test descriptions, not files, so its verdict sources are pinned only
  through the receipt step's argv file operands; a test file it imports is not pinned.
- A caller of `Verifier.run/2` that supplies no `:base_sha` is not pinned. `SemanticWork` always
  records one and `Lease.close/4` passes it, so every semantic Run is pinned.
- Log verification detects tampering and hand-written events; a forger who can write the log
  directory and recomputes digests is not detected (the directory is the trust root).
- `reap_orphaned_claims/1` is only safe while no other writer is mid-append to that directory.
- An orphaned claim still costs the 5 s `TransitionLog.await/3` before the bridge refuses.
- Upstream `transition-store` (a parallel branch) moves the event digest into `Store.event_digest/1`
  with a golden on-disk fixture built by the old rule: the integrator must switch that line to
  `digest_exact` and regenerate the fixture (or rely on `legacy_event_digest/1` for the old one).

### Mutants killed

Bypass of the OS lock (race test red: six appended); pin disabled (2 court-mode provenance tests
and 6 verifier tests red); replace-ref defences removed (refs/replace test red; either defence
alone is enough and is not distinguishable, so the mutant removes both); legacy `"binding"` drop
off (verifier legacy test red); log derivation off, chain check off, shape check off, orphan
acknowledgement off (each red in the integrity/falsifier suites). The export-level provenance gate
and the verifier drop are independent layers, so removing only one leaves the forged-court test
green by design.

### Verification, repair round (2026-09-21, `MIX_TEST_PARTITION=r1`, load average above 60)

| Check | Result |
|---|---|
| Qualifier reds before the fix (forged, falsifier, orphan) | 15 tests, 13 failures |
| Same three files after | 15 tests, 0 failures |
| The 11 bridge, crown, receipt, guard files, `--include subprocess` | 131 tests, 0 failures |
| Verifier, lease-verifier, court-receipt suites | 75 tests, 0 failures |
| ggen_igniter `203cecb`: digest, reconciler, crown, descriptor | 26 tests, 0 failures |
| `test/xaas/ultracode` whole directory, `--include subprocess` | 655 tests, 1 failure (below) |
| `mix format --check-formatted`, every touched file | clean |
| Mock grep over `test lib` | 1 hit: a regex string in `xaas.verify_and_commit.ex`, as at base |
| `mix credo --strict`, touched files (scratch runner) | 4 findings, all in older code |
| `mix compile --force --warnings-as-errors` | exit 1: only older `castle.ex`, `computation.ex` |

Failures, and whether this round introduced them:

- `AutonomicMultiRepoTest` failed once in the 279 s whole-directory run with a
  `DBConnection.OwnershipError` in the middle of a long test. Alone it passes (1 test, 0 failures,
  112.4 s), close to the 120 s default sandbox ownership timeout, so the cause is UNVERIFIED but
  consistent with load. Not introduced here: the previous round saw the same test fail in the same
  directory run with a different symptom (`PARTIAL_ALIVE`).
- `Xaas.Zoe.EventSimulationZoeTest` (4 tests, `{:error, {:invalid, :event_id}}`) fails when the zoe,
  a2a, gall and zcode_plugin directories are run. It is a pure module that references nothing
  touched here, and `lib/xaas/zoe` and `test/xaas/zoe` are identical to the base SHA. Pre-existing.
- credo: `lease.ex` `select_and_bind` and `do_claim_next`, `verifier.ex` `run_step` and
  `contained_worktree`. None is in code added this round.

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
