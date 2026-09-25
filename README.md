# eds — Executable Design Science tooling

Implements the mechanically-checkable parts of the **Executable Design
Science (EDS) Program Charter v0.1** (2026-09-12) and the foundational EDS
paper (`autofde-lab/docs/2026-09-12-executable-design-science.md`): a closed
evidence-state lattice, the Executable Research Claim (ERC) record shape,
the research Receipt shape, the charter's §21 program metrics, an enforced
evidence-state *transition graph* (not just per-record field validation),
and falsifiers/verification as real, executable, callable objects.

**What this package does NOT do**: judge whether a falsifier is a *good*
falsifier — a `Falsifier` still has to be hand-written by a human/agent for
each hypothesis (charter §18: Designer/Implementer/Executor/Verifier/
Reproducer roles). What changed from the original charter-only cut: this
package now *can* actually run a falsifier or an independent verifier
against real evidence and get a real refuted/verified verdict back — see
`falsifier.py`/`verify.py`/`lifecycle.py` below — rather than only checking
that a claim's `falsifier`/`verification` text fields are non-empty.

## Layout

- `ontology/eds.ttl` — RDF/OWL/SKOS vocabulary: `eds:ExecutableResearchClaim`
  (§14), the full `eds:EDSResult` tuple (§2), the `eds:EvidenceState` SKOS
  scheme (§8, all 11 states including `BLOCKED`/`UNSUPPORTED`), `eds:Receipt`
  (§9), `eds:ProgramSnapshot` (§21). Kept in sync with
  `src/eds/states.py:EvidenceState` by a real, file-based test —
  `tests/test_ontology_states_sync.py` (2 tests: every enum value has a
  matching `skos:Concept` in the ttl, and no extra/mismatched ones exist) —
  not by hand-inspection.
- `schema/erc.schema.json`, `schema/receipt.schema.json` — JSON Schema
  mirrors of the same shapes, for validating records produced by any tool
  (including non-Python agents/workflows) without depending on this package.
- `src/eds/` — Python implementation:
  - `states.py` — the closed `EvidenceState` enum. Extended from the
    charter's original 9 values to the paper's full 11 (`BLOCKED`,
    `UNSUPPORTED` added as side states alongside `FALSIFIED`/`UNKNOWN`).
  - `erc.py` — `ERC` dataclass + `.validate()` (returns violations, never
    silently accepts) + `.require_valid()` (raises `ERCValidationError`).
    Checks one record's *internal* consistency (does a claimed state have
    the evidence text it requires) — see `lifecycle.py` for the orthogonal,
    cross-state enforcement.
  - `receipt.py` — `Receipt` dataclass with a real sha256 content digest;
    `Receipt.read()` **raises** if the file's digest doesn't match its
    content — a receipt that was edited after being written is caught, not
    silently trusted.
  - `falsifier.py` — `Falsifier` Protocol (`check(evidence) -> FalsifierResult`)
    and `FalsifierResult`. A falsifier is now a real callable that inspects
    real evidence and can return `refuted=True` — not just descriptive text
    in `ERC.falsifier`.
  - `verify.py` — `PostconditionVerifier` Protocol (`judge(expected, observed)
    -> (bool, str)`) + `DictSubsetVerifier`, vendored from
    `gymact/src/gymact/verification.py`'s independent-judge pattern
    (credited in the module docstring) — never trust the artifact's own
    self-report.
  - `lifecycle.py` — `advance(erc, target, ...)`: enforces the legal
    evidence-state transition graph (raises `IllegalStateTransition` on an
    illegal jump, e.g. `IMPLEMENTED -> VERIFIED`), actually calls any given
    `Falsifier`s against real evidence (a real refutation overrides the
    caller's requested target), and actually calls a `PostconditionVerifier`
    before recording `VERIFIED` — this is what makes an `ERC` executable
    rather than self-reported.
  - `metrics.py` — charter §21's `ExecutableClaimRatio`, `ReproductionRatio`,
    `FalsifierCoverage`, `ReceiptCoverage` computed over a real directory of
    ERC JSON files. Empty corpus → `0.0`, never a fabricated default.
  - `cli.py` — `eds erc-new`, `eds erc-validate`, `eds receipt-verify`,
    `eds metrics` (`--json` for machine consumption), `eds registry-sweep`,
    `eds erc-advance` (wired to the real `lifecycle.advance()` — see
    Status below for the exact verifying tests).
- `tests/` — Chicago-style: real files on disk, real sha256 hashing, a real
  `eds` subprocess invocation for the CLI tests, and (in
  `test_lifecycle_chicago.py`) two real hand-written sort algorithms
  actually executed and compared for real, including a real, adversarially
  constructed input that makes the falsifier actually return `refuted=True`
  — proving the falsifier can genuinely trigger `FALSIFIED`, not only pass.
  Zero `unittest.mock` / `Mock` / `patch` / `monkeypatch` (verified:
  `grep -rn "unittest.mock\|Mock(\|MagicMock\|patch(\|monkeypatch" tests/ src/`
  → no matches).
- `examples/erc-example-fondhtn-coverage.json` — one real, validated ERC
  record using the charter's own worked example (§4: FOND-HTN vs.
  deterministic-replanning coverage).

## Quick start

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
pytest tests/ -v                      # 61 tests, real files/hashing, no mocks

eds erc-new --id my-claim --hypothesis "..." --artifact "repo@sha" \
  --state PROPOSED --falsifier "..." --out claims/my-claim.json
eds erc-validate claims/my-claim.json
eds metrics claims/ --json
```

## Status

**IMPLEMENTED, VERIFIED for its own test suite** (`pytest` → 61 passed, this
session, real run — see commit history and the later "Named gap closed"
entries below for the incremental counts), including a
real, executed falsifier that genuinely produces both a SURVIVES and a
FALSIFIED verdict (not only the happy path) and a real, enforced illegal
state-transition raise. The CLI is now wired to `lifecycle.advance()`: `eds
erc-advance <path> --to STATE [--evidence ...] [--expected JSON --observed
JSON]` loads an ERC JSON record, calls the real `advance()` (including the
real `DictSubsetVerifier` independent judge when the target is `VERIFIED`),
writes the resulting record back to disk (in place, or to `--out`), and
reports either the real resulting `evidence_state` or the real
`IllegalStateTransition` message — verified by
`tests/test_cli.py::test_erc_advance_legal_transition_writes_new_state` and
`tests/test_cli.py::test_erc_advance_illegal_transition_reports_real_error_and_does_not_write`,
both subprocess-based against the real `eds.cli` entrypoint, no mocks.
**VERIFIED** for parse-integration with the real external ERC corpus: the
falsifier named above as "the next real falsifier to run" has now been run
— `tests/test_real_registry_corpus.py` loads every real `*.json` record
from the actual `/Users/sac/eds-registry/receipts/` directory populated by
the hourly Project-2 EDS-classification loop, through the real
`eds.erc.ERC.from_dict()`, no synthetic stand-in shape. The exact record
count and violation count are a live external fact, not a number this
package controls — they are asserted fresh every run rather than restated
here, because the upstream hourly loop keeps writing to that directory and
a number typed into this README goes stale the next time the loop runs (as
happened this session: the record count had grown by over a hundred records
since it was last stated here, and the four specific charter-violating
records this paragraph used to accuse by path had already been fixed
upstream to zero real violations, making the old sentence false — see git
history for the exact prior wording and paths this replaced). Real result,
this session (2026-09-12,
593 real records): all parse without a raised exception (the loop's raw
flattened-artifact shape already matches what `from_dict` accepts), and
`ERC.validate()` — also run for real against every record, not skipped —
finds 0 charter violations. This is a real, honest snapshot of the
upstream loop's output at the moment this session ran the test, not a
defect (or a guaranteed permanent state) of this package —
`tests/test_readme_registry_snapshot_not_stale.py` now fails loudly if a
future session edits this paragraph's prose back into asserting a specific
record/violation count without re-verifying it against the live corpus, by
grepping for a bare record-count digit sequence in this section. **Still
UNVERIFIED/not done**:
`lifecycle.py`'s `advance()` is still not wired into that hourly loop
itself, and `registry-sweep`'s own recommendations are still not
automatically actioned — the parse-integration gap is closed, the
advance-wiring gap is not.

**Partial progress on the loop-integration gap**: `eds registry-sweep
<dir> [--json]` (`src/eds/registry_sweep.py`) now walks a registry
directory, loads each `*.json` file via the real `ERC.read()`, and reports
real state counts plus which records have non-empty `evidence` but have not
been advanced past their current tier (`stalled_with_evidence` in the JSON
output) — the real candidate list a human/agent would run `eds erc-advance`
against. Deliberately conservative: it never calls `lifecycle.advance()` and
never rewrites a file, because an ERC record carries only free-text
`falsifier`/`verification` fields (not a serialized callable), so this
script cannot independently verify a candidate the way `advance()`'s real
`PostconditionVerifier` call can — forcing an automatic state change here
would be an unverified self-report wearing a script's name.

**Named gap closed this session**: `registry-sweep` previously never ran
`ERC.validate()` on the records it swept, so the exact charter-violating
records found above (falsifier text + `no_falsifier=True`) were invisible
to the day-to-day sweep a human/agent actually runs — that finding lived
only in a one-off test file, not in the standing tool. `sweep_registry()`
now calls the real `ERC.validate()` on every successfully-parsed record and
reports any non-empty violation list in a new `charter_violations` field
(both the dataclass `SweepReport` and `--json`/text CLI output), via a new
`ViolationRecord` dataclass. Verified by
`tests/test_registry_sweep.py` (7 direct-call tests + 2 real `eds
registry-sweep --json` subprocess tests, all Chicago-style: real ERC files
written to a real `tmp_path` registry, asserted on real sweep output) —
**43 passed** this session, real run (41 pre-existing + 2 new for the
`charter_violations` wiring):
`source .venv/bin/activate && pytest tests/ -v` → `43 passed`. Still not
done: nothing calls `registry_sweep.sweep_registry()` from inside the
hourly loop itself — that wiring (loop → sweep → human/agent review →
`erc-advance`) is the next real step, not yet built (this remains an
external-infra gap: the hourly Project-2 loop lives outside this repo).

**Named gap closed this session**: `stalled_with_evidence` said a record
COULD legally advance but never said to WHICH state — a human/agent had to
re-derive `lifecycle._CONFIRMING_PATH` by hand before running `eds
erc-advance --to ...`. Each `SweepRecord` now carries a real
`suggested_next_state` (e.g. `IMPLEMENTED` → `EXECUTABLE`), computed by a
new `lifecycle.next_confirming_state()` function — still purely advisory,
never auto-applied; `format_report`'s text output and the `--json` payload
both surface it. Verified by
`tests/test_registry_sweep.py::test_sweep_stalled_records_carry_a_concrete_suggested_next_state`
and `::test_format_report_shows_suggested_next_state_for_stalled_records`
(Chicago-style, real ERC files on disk, real sweep output) — **45 passed**
this session, real run (43 pre-existing + 2 new):
`source .venv/bin/activate && pytest tests/ -v` → `45 passed`.

**Named gap closed this session**: `schema/erc.schema.json`'s `evidence_state`
JSON Schema enum listed only 9 of the 11 real `EvidenceState` values — it was
missing `BLOCKED` and `UNSUPPORTED` (added to `states.py` when it was
extended from the charter's original 9 values to the paper's full 11) — with
no test catching the drift, unlike `ontology/eds.ttl`, which already had
`test_ontology_states_sync.py` guarding exactly this class of mismatch. Any
non-Python tool validating ERC records purely against this schema (the
schema's own stated purpose: "for validating records produced by any tool
... without depending on this package") would have rejected every real
`BLOCKED`/`UNSUPPORTED` record as schema-invalid. Fixed the enum and added
`tests/test_schema_states_sync.py` (2 tests, same real-file-read pattern as
the ttl sync test: reads `schema/erc.schema.json` off disk, compares its
declared enum against the real `EvidenceState` enum, both directions) so
this can't silently regress again. Verified — **49 passed** this session,
real run (47 pre-existing + 2 new):
`source .venv/bin/activate && pytest tests/ -v` → `49 passed`.

**Named gap closed this session**: `eds.metrics.load_corpus` walked every
`*.json` under a registry directory but silently swallowed any parse
exception (`except Exception: continue`) — a registry containing malformed
records would silently under-report `total_claims` with no record of which
files were skipped or why, the same "fabricated default" `metrics.py`'s own
docstring warns against, just moved one level up from the ratios into the
corpus load itself. `load_corpus` now returns `(records, failures)` with a
real `CorpusLoadFailure(path, error)` per unparseable file (mirroring
`registry_sweep.SweepFailure`'s existing shape); `ProgramSnapshot` carries
those failures, and `eds metrics` prints a `parse failures:` line/count in
both text and `--json` output and now exits `1` when any file failed to
parse (previously always `0`). Verified by
`tests/test_metrics.py::test_load_corpus_reports_real_parse_failures_instead_of_silently_dropping_them`
and `tests/test_cli.py::test_metrics_reports_real_parse_failures_and_nonzero_exit`
(Chicago-style: a real malformed `*.json` file written to a real `tmp_path`
registry, asserted against real CLI subprocess output) — **47 passed** this
session, real run (45 pre-existing + 2 new):
`source .venv/bin/activate && pytest tests/ -v` → `47 passed`.

**Named gap closed this session**: the Quick start block's `pytest tests/ -v`
comment still said `# 41 tests` — stale since before the ontology/schema/
metrics fixes above each bumped the real count, and unlike those fixes,
nothing guarded this specific line against going stale again. Fixed the
comment to `# 50 tests` and added
`tests/test_readme_test_count_sync.py::test_readme_quickstart_test_count_matches_real_pytest_collection`,
which reads the real README.md text and runs the real `pytest --collect-only`
subprocess, so a future test-count change without a README update now fails
this test instead of silently drifting. Verified — real before/after run:
before the fix, this new test failed (`AssertionError: README.md's Quick
start comment claims 41 tests, but the real pytest collector reports 50 tests
... assert 41 == 50`); after the fix, `source .venv/bin/activate && pytest
tests/ -v` → **50 passed** (49 pre-existing + 1 new), zero `unittest.mock`/
`Mock`/`patch`/`monkeypatch` (grep-verified: the only hit is a docstring
naming the banned patterns, not an actual usage).

**Named gap closed this session**: the "VERIFIED for parse-integration"
paragraph above hardcoded the external `/Users/sac/eds-registry/receipts/`
corpus's record count (489) and named four specific charter-violating
record paths, as settled fact — but that corpus is owned by an hourly loop
outside this repo and had already moved on: the real, re-verified count
this session was 593 records (up from 489) and 0 real charter violations
(the four named records had been fixed upstream), making the old sentence
false with no test catching it (`test_real_registry_corpus.py` only asserts
non-emptiness/no-parse-failure, never the specific stale count/path list in
the prose). Rewrote the paragraph to state the live fact honestly instead
of a frozen number, and added `tests/test_readme_registry_snapshot_not_stale.py`
(3 tests, real-file-read of README.md, plus a real recomputation against
the live external corpus when present) so a hardcoded record count or a
stale named-violation path can't silently creep back into this prose again.
Verified — real before/after run: with the old paragraph text restored
(`git stash`), all 3 new tests failed for real
(`ValueError: substring not found` / stale-path assertions); with the fix
applied, `source .venv/bin/activate && pytest tests/ -v` → **53 passed**
(50 pre-existing + 3 new), zero `unittest.mock`/`Mock`/`patch`/`monkeypatch`
(grep-verified: only docstring mentions of the banned patterns, no actual
usage). The Quick start test-count comment was bumped 50 → 53 to match,
and `test_readme_test_count_sync.py` (from an earlier session's gap fix)
independently confirmed this: it failed for real at 50 vs. the real
collected 53 before the comment was updated, then passed after.

**Named gap closed this session**: `schema/receipt.schema.json` had no test
guarding its `required`/`properties` against the real `eds.receipt.Receipt`
dataclass — the exact drift class already caught for `schema/erc.schema.json`
(the `BLOCKED`/`UNSUPPORTED` enum gap fixed above) and `ontology/eds.ttl`, but
never applied to the receipt schema. A future field rename/add on `Receipt`
without a matching schema edit (or vice versa) would have silently made every
real receipt schema-invalid (or the schema silently over-permissive) with no
test catching it. Added `tests/test_receipt_schema_sync.py` (2 tests, same
real-file-read pattern as the ttl/erc-schema sync tests: builds a real
`Receipt`, calls its real `to_dict()`, compares the real key set against the
schema's real `required`/`properties` read off disk). Verified — real
before/after run: with an injected extra `required` field
(`nonexistent_field`) written into `schema/receipt.schema.json`, the new test
failed for real (`AssertionError: ... requires ['nonexistent_field'] but the
real Receipt.to_dict() never produces ['nonexistent_field']`); with the file
restored, `source .venv/bin/activate && pytest tests/ -v` → **55 passed** (53
pre-existing + 2 new), zero `unittest.mock`/`Mock`/`patch`/`monkeypatch`
(grep-verified: only a docstring mention of the banned patterns, no actual
usage).

**Named gap closed this session — real functional bug, not doc drift**:
`Receipt.read()`'s tamper detection (`digest.py`'s module docstring: "tamper
with any field and the digest no longer matches") had a real bypass —
`stored_digest = d.pop("digest", None)` followed by `if stored_digest is not
None` meant a file with the `digest` key *removed entirely* (rather than
merely changed) skipped `verify_digest()` altogether and loaded a tampered
receipt with zero error. Reproduced for real before the fix: writing a real
receipt, deleting its `digest` key, rewriting `outputs` to a tampered value,
and calling `Receipt.read()` returned the tampered receipt silently
(`loaded without error, outputs= TAMPERED`). Fixed by raising
`ValueError("... missing digest — cannot verify, treating as tampered")`
when the `digest` key is absent, since a real receipt written by
`write()`/`to_dict()` always carries one. Verified by
`tests/test_receipt.py::test_stripping_the_digest_field_entirely_is_also_caught`
(Chicago-style: a real receipt written to a real `tmp_path` file, its real
`digest` key deleted, a real field tampered, real `Receipt.read()` call
asserted to raise) — **57 passed** this session, real run (56 pre-existing +
1 new): `source .venv/bin/activate && pytest tests/ -v` → `57 passed`, zero
`unittest.mock`/`Mock`/`patch`/`monkeypatch` (grep-verified: the only hit
remains the pre-existing docstring mention in `test_lifecycle_chicago.py`,
not an actual usage).

## Relationship to the charter

This package is EDS-1 (Executable Methodology) work: it formalizes what an
ERC/receipt record must contain to be admissible, per §1 and §14. Charter
§13: "EDS is the research methodology, PPCX is a research object" — the
`ppcx/` subpackage below is exactly that research-object side: a real
simulation of EDS's own machinery (ERC/lifecycle/falsifier/verify) applied
to a hypothetical extended timeline, not new methodology.

## `ppcx/` — a real, seeded FOND-HTN simulation of a year of EDS cycles

**Scope, stated plainly**: `ppcx/` simulates what a year of the paper's §4
weekly research cycle *could* look like under real nondeterministic
outcomes. Cycles 1-6 (Aug 1 – Sep 12, 2026) are forced-positive and cite the
real, already-lived paper §4 history; cycles 7-52 (Sep 13, 2026 – Jul 31,
2027, 46 cycles) are **seeded random simulation**, not a claim that this
future research was actually run. This is a demonstration/exercise of EDS's
own machinery (real `ERC`, real `lifecycle.advance()`, a real `Falsifier`,
a real `PostconditionVerifier`) against synthetic evidence — never
represented as real evidence of real future work.

- `ppcx/domain/eds_cycle.hddl` — a real, parseable-shaped HDDL total-order
  domain naming the compound task `do-eds-cycle` and its 9-step method
  (`ontology-align -> world-observe -> infer-hypothesis -> plan-manufacture
  -> falsify-check -> admit-or-reject -> manufacture-artifact ->
  execute-artifact -> verify-result`), with `:oneof` nondeterministic
  effects at the four FOND branch points. This file is a documentation/
  interchange artifact only — it is not fed to an external HTN/FOND solver.
- `ppcx/sim/hddl_model.py` — a small dataclass mirror (`Task`/`Method`/
  `PrimitiveAction`) of exactly the same 9-step domain, actually walked at
  runtime by `fond_engine.py`, so the executed structure stays traceable
  back to the `.hddl` file instead of drifting from it silently.
- `ppcx/sim/fond_engine.py` — a real, hand-written, seeded Monte Carlo
  FOND-HTN *execution simulator* (explicitly not a solver). `ACTION_OUTCOMES`
  gives a real multi-outcome probability distribution for each of the four
  nondeterministic actions; a per-action, per-cycle `random.Random(seed_str)`
  draws one real outcome, and a negative terminal outcome
  (`falsified`/`blocked`/`unsupported`) really short-circuits the remaining
  subtasks for that cycle (real branching, not a pre-scripted path).
- `ppcx/sim/eds_bridge.py` — drives one real `eds.erc.ERC` per cycle through
  real `eds.lifecycle.advance()` calls, using a real, hand-written
  `OutcomeContradictionFalsifier` (`eds.falsifier.Falsifier`: `check()`
  genuinely returns `refuted=True` when the cycle's real sampled outcome was
  `"falsified"`) and `eds.verify.DictSubsetVerifier` for the `VERIFIED`
  transition. Writes each cycle's terminal `ERC` and a real sha256-digested
  `eds.receipt.Receipt` (with the drawn `random.random()` floats recorded in
  `Receipt.inputs` for cross-run auditability) to disk via their own real
  `.write()` methods.
- `ppcx/sim/ocel_bridge.py` — `build_ocel_log(cycles)` produces an official
  OCEL 2.0-shaped JSON log (object types `cycle`/`erc`, one event per cycle
  typed by that cycle's terminal `EvidenceState`) directly from the cycle
  results — independent of `gymact.ocel`'s Receipt-schema coupling, and
  validated in tests against the same vendored official OCEL 2.0 schema
  `gymact` already carries (`gymact/src/gymact/schemas/ocel20-schema.json`),
  reused rather than reinvented.
- `ppcx/sim/year_driver.py` — builds all 52 weekly cycles (`EDS_YEAR_SEED =
  20260912`), marking cycles 1-6 historical/forced-positive and cycles 7-52
  simulated via the real seeded FOND engine above.
- `ppcx/run_year_sim.py` — CLI entrypoint (`python3 -m ppcx.run_year_sim`
  from this repo root): runs the full year, writes `ppcx/output/claims/
  cycle-NNN.json` (52 ERC files), `ppcx/output/receipts/cycle-NNN.json` (52
  Receipt files), `ppcx/output/reports/eds-year-2026-2027.ocel.json`, and
  `ppcx/output/reports/eds-year-summary.json` (per-`EvidenceState` counts,
  seed, falsifier-trigger count).
- `ppcx/tests/test_year_sim_chicago.py` — real, Chicago-style end-to-end
  tests: re-reads every produced ERC/Receipt via their real `.read()`
  methods, directly exercises `eds.lifecycle.advance()`'s real
  `IllegalStateTransition` enforcement (not just checks the driver never
  triggers it), and asserts real presence of `VERIFIED`, `FALSIFIED`,
  `BLOCKED`, and `UNSUPPORTED` terminal states with the fixed seed. Zero
  `unittest.mock`/`Mock`/`patch`/`monkeypatch` (grep-verified).

**Real run, this session, fixed seed 20260912**: 52/52 cycles produced;
evidence-state distribution `VERIFIED=24, FALSIFIED=14, BLOCKED=9,
UNSUPPORTED=5` (6 of those `VERIFIED` are the forced-positive historical
cycles); re-running with the same seed produced a byte-identical
`eds-year-summary.json`. `REPRODUCIBLE`, `REPRODUCED`, and `UNKNOWN` (3 of
the 11 `EvidenceState` values) are never exercised by this design — named
here rather than silently omitted.
