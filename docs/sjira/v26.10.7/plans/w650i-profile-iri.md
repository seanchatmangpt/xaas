# W650i — profile.shacl.ttl IRI repair (W640 finding b)

Lane W650i, v26.10.7 fleet seal. Date: 2026-10-07. Repo: `/Users/sac/xaas`,
branch `feat/playwright-surface`. NOT committed (lane contract). Files
written: `lib/mix/tasks/xaas.airo.compile_shacl.ex` (generator source), the
regenerated `priv/airo/profile.shacl.ttl` artifact, this receipt.

## The fix

One-string generator repair: the `airo-sh:` prefix IRI
`https://w3id.org/airo#shapes#` (illegal second `#` inside an IRI) →
`https://w3id.org/airo#shapes-`, applied at the GENERATOR source
(`render/0` header, line 198 of the task file), not only the artifact.
Artifact regenerated via the generator itself
(`Mix.Tasks.Xaas.Airo.CompileShacl.run/1` — class_census 46, shapes_emitted 46,
triples_emitted 130; round-trip gate passed). Generation is stable.

## Digests (before → after)

- `priv/airo/profile.shacl.ttl`:
  `2a32a82c20db61128dcbd93a9503fd89705e9124bab84e1ed45a9404df0b762b` →
  `26db08fade5f0b333c2ef3a2e667f89fd4922b7de869d1f72bb1e4d1db2724a3`
  (SHA-256; **shapes-digest rotation disclosed** — every downstream pin of
  the profile digest must rotate).
- Generator file: source edit, not digest-pinned.
- graphlaw artifact pin unchanged: `fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38`
  (verified `verify_digest/2` per court boot).

## Verification (real commands, real tails)

1. **Strict Turtle**: `RDF.Turtle.read_string/1` on the raw emitted bytes →
   `OK triples=130` (mix run, MIX_ENV=test, `_build-laneW650i`).
2. **Guest dialect check (raw bytes, direct witness)**: `op:"shacl"` through
   digest-pinned W637 artifact on a real WASI store with the RAW
   `priv/airo/profile.shacl.ttl` bytes as shapes →
   `guest_raw_bytes: %{ok: true, results: 0, conforms: true}`. The W640
   C0 typed refusal (`EngineRejected/Turtle/iri-disallowed-char`) has flipped
   to acceptance, as predicted.
3. **W640 differential court + W615 airo_shacl court**, ×2 fresh roots
   (`_build-laneW650i`, `_build-laneW650i-r2`):
   `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650i[-r2] mix test test/xaas/semantics/w640_differential_shacl_test.exs test/xaas/airo_shacl_court_test.exs`
   → `Result: 10 passed` both runs (7.3s / 6.3s tails). C1–C4 host/guest
   agreement holds on the new shapes bytes; C0 asserts (post-W650f2 flip)
   guest admission + host/guest conforms agreement on the raw profile.
4. **W615 census**: `W615 court run 1/2: OK (census=46, triples=130)` in the
   test output — the court's independent re-derivation matches the
   generator's stats.

## Court-file concurrency note (disclosed)

My first court run (launched ~15:05) hit a stale C0 assertion
(`assert resp["ok"] == false` at w640_differential_shacl_test.exs:79) — the
court file was updated mid-flight by the W650f/W650f2 lane to the
post-repair expectation (their moduledoc cites "w650i finding-(b) repair,
w650f stale-court witness"). Re-run on the current disk state: 10/10. The
first failure was a stale assertion against the pre-repair world, not a
defect in the repair.

## Standing

**ALIVE** (one-string generator repair, ×2 fresh roots): the emitted profile
parses as strict Turtle, is admitted by the graphlaw guest dialect check on
its raw bytes, C1–C4 differential agreement holds, W615 census court passes.
W640 finding (b) is CLOSED. Finding (c) (GraphlawWasm zero-stub trap) remains
OPEN elsewhere — out of lane scope; the court's real-WASI transport is
unchanged.

## Boundary / next

- Shapes-digest rotation: downstream consumers pinning the old profile
  digest `2a32a82c…` must rotate to `26db08fa…`.
- `_build-laneW650i` and `_build-laneW650i-r2` NOT deleted: lane `rm -rf`
  denied by the session permission system (same denial W640 recorded) —
  left for the coordinator per lane contract.
- Transport failures (recorded): background-task 30-minute limit killed two
  fresh-root compile attempts; third attempt on the resumed root completed.
  `GraphlawWasm.invoke/3` takes the instance map, not the pid (first direct
  witness attempt raised FunctionClauseError; repaired forward).
