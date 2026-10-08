# W650f2 — C0 flip receipt (v26.10.7 fleet seal)

Lane: W650f2 (court owner delegated per W650f's note,
[w650f-unification-verify.md](w650f-unification-verify.md)). Date 2026-10-07.
Subject: branch `feat/playwright-surface`, working tree at time of writing
(HEAD `87dc84de`); NOT committed (coordinator owns transitions).

## C0 before / after

File: `test/xaas/semantics/w640_differential_shacl_test.exs`

**Before (W640 original)**: C0 asserted guest TYPED refusal of the raw
`priv/airo/profile.shacl.ttl` bytes — `ok:false`, `EngineRejected`,
`dialect: "Turtle"`, message `~="iri-disallowed-char"` (the illegal second `#`
in the `airo#shapes#` prefix IRI, W615 generator defect, finding (b)).

**After (W650f2 flip)**: C0 asserts guest ADMISSION of the repaired bytes:
`ok:true`, plus the court's agreement predicate — host `violations/1`
focus set vs guest conforms-boolean agreement on the profile-bytes surface.
Original typed-refusal history preserved as a comment block above the test
citing w650i's profile repair + w650f's stale-court witness. Moduledoc C0
line updated to match.

## Repair provenance

- w650i's profile repair: `priv/airo/profile.shacl.ttl` on disk now contains
  0 occurrences of `airo#shapes#`, 1 of `airo#shapes-` (witnessed by grep
  this lane). The w650i receipt file itself is NOT on disk under
  `docs/sjira/v26.10.7/plans/` as of this lane (w650h2 also records it as
  not landed); the repair is witnessed on-disk + by w650f's stale-court
  disclosure.
- w650f's witness: w650f-unification-verify.md — C0 was the only failing
  case at 15:18, traced to the finding-(b) repair, not digest drift; C1–C4
  agreement rows passed on the same run.

## Court runs (real tails, ×2)

Environment: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
MIX_BUILD_ROOT=_build-laneW650f2 mix test test/xaas/semantics/w640_differential_shacl_test.exs`

Run 1 (exit 0):
```
.....
Finished in 6.4 seconds (0.00s async, 6.4s sync)
Result: 5 passed
```

Run 2 (exit 0):
```
.....
Finished in 6.3 seconds (0.00s async, 6.3s sync)
Result: 5 passed
```

## Digest witnessed

`fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38`
(sha256 of `priv/graphlaw.wasm` on disk, re-read this lane; == pin file
`priv/graphlaw.wasm.sha256`). Both runs executed the court's digest-pin leg
against fc23a292 (post-rotation artifact). The w640 receipt's ×2 5/5 runs
witnessed b7664a5e pre-repair; the C0 discrepancy across digests is the
finding-(b) repair, not digest drift (w650f trace).

## Unification receipt §7 update

`_GRAPHLAW_WASM_UNIFICATION_RECEIPT.md` §7.1 added: C0 dual-digest row —
b7664a5e TYPED REFUSAL pre-repair (w640 receipt) vs fc23a292 ADMISSION
post-repair (w650f + this receipt). C1–C4 unchanged.

## Standing

**ALIVE (differential agreement on fc23a292, C0 flipped, 5/5 ×2)**. C1–C4
AGREE rows unchanged. NOT asserted: SHACL conformance beyond the corpus;
zero-stub WASI real-workload execution (W640 finding (c), still open).

## Falsifiers / disclosures

- None fired this lane: 5/5 ×2 on the flipped C0 as predicted by w650f.
- Disclosure: the court's `@shapes` repair transform
  (`airo#shapes#` → `airo#shapes-`) is now a byte-level no-op on the
  repaired disk profile; the flipped C0 asserts `@shapes == @raw_shapes` as
  a witness of that no-op, so any regression of the profile back to the
  illegal IRI re-fires C0 as a failure.

## Replay

```
shasum -a 256 priv/graphlaw.wasm
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650f2 \
  mix test test/xaas/semantics/w640_differential_shacl_test.exs   # expect 5/5
grep -c "airo#shapes#" priv/airo/profile.shacl.ttl                 # expect 0
```
