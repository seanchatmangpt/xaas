# W82 oracle rerun receipt — vector-3 suites under the settled tree (v26.10.6)

Subject: /Users/sac/xaas @ d1db2b03179975213c14663b9dbd86b5ac2a14cf (branch
`feat/playwright-surface`) + sibling /Users/sac/ggen_igniter @
7dbcdb3a050ea4b2ce4d5f047ed2913052b5b539 (working tree modified in-flight:
`lib/ggen_igniter/gate_verify.ex`, `lib/ggen_igniter/pack_catalog.ex`, docs;
`priv/ggen` dir mtime today 11:27). Date: 2026-10-06. MIX_ENV=test, pinned asdf
toolchain (`PATH=$HOME/.asdf/shims:$PATH`), `GGEN_IGNITER_DIR=/Users/sac/ggen_igniter`
exported for every run. Receipt-only lane: no fixes, no git mutations, no test-code
edits.

Command form (per suite):

```
PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test \
  mix test <file>
```

## 1. Per-file counts (verbatim ExUnit `Result:` lines, one run per file)

| # | file | result | vs. vector-3 receipt |
|---|---|---|---|
| 1 | `test/xaas/receipt/r_projection_test.exs` | `Result: 9 passed` | unchanged (9 passed, 0 skipped) |
| 2 | `test/xaas/receipt/r_projection_consistency_test.exs` | `Result: 18 passed` | unchanged (18 passed, `GGEN_IGNITER_DIR` export satisfies the gate) |
| 3 | `test/xaas/ultracode/origin_authority_test.exs` | `Result: 5 passed, 5 skipped` | **REGRESSED vs vector-3** (was 10 passed, 0 skipped with the same export). §2.1. |
| 4 | `test/xaas/ultracode/semantic_drive_anchor_test.exs` | `Result: 6/8 passed` — `Failed: 2 tests` | **FAILURE MODE CHANGED** (was 6 passed / 2 FAILED on `mu_on_O` REFUSED; now setup MatchError). §2.2. |
| 5 | `test/xaas/sjira/yield_test.exs` | `Result: 8 passed` | unchanged. Also answers vector-3's open question: 0 skipped while `autofde` is absent — confirmed twice, this file's skip topology on this HEAD does not skip on missing autofde. |
| 6 | `test/xaas/sjira/successor_test.exs` | `Result: 8 passed` | unchanged (8 passed, rdflib oracle LIVE) |
| 7 | `test/sjira/v26_9_23_goal_test.exs` | `Result: 20/37 passed` — `Failed: 17 tests` | was BLOCKED(checkout_compile_outage); now runs, 17 real failures. One root cause, §2.3. |
| 8 | `test/mix/tasks/xaas_stop_court_test.exs` | `Result: 7/19 passed` — `Failed: 12 tests` | was BLOCKED(checkout_compile_outage); now runs, 12 real failures. Same root cause, §2.3. |

Bulk run of files 1–6 in one command: `Result: 54/56 passed, 5 skipped` /
`Failed: 2 tests` (5 skips = origin_authority's describe-block skip; 2 failures =
anchor). Files 7+8 together: `Result: 27/56 passed` / `Failed: 29 tests`.

## 2. Classification (receipt-only; nothing fixed)

### 2.1 origin_authority: 5 skipped — sibling `_build` absence, not xaas-side regression

Gate (test/xaas/ultracode/origin_authority_test.exs:34-38):

```elixir
@ggen_dir System.get_env("GGEN_IGNITER_DIR") || Path.expand("~/ggen_igniter")
@ontology Path.join(@ggen_dir, "priv/ggen/semantic-jira-pack/ontology.ttl")
@ggen_ready File.regular?(@ontology) and
              File.read!(@ontology) =~ "a sj:AuthorityTrustRoot" and
              File.dir?(Path.join(@ggen_dir, "_build/test/lib/ggen_igniter"))
```

All three conditions re-checked on disk this session: ontology.ttl present and
readable (`-rw-r--r-- sac`, 161205 bytes, contains the `sj:AuthorityTrustRoot` pin),
but `/Users/sac/ggen_igniter/_build/` does not exist at all. `@ggen_ready` is
compile-time-false, so the describe block "the real G1 kernel in the ggen_igniter
checkout" skips by name (origin_authority_test.exs:104-107) — 5 tests. The five
non-gated tests pass.

Verdict: NOT an xaas-side code regression. The ggen_igniter sibling moved since
vector-3 ran (its HEAD is now 7dbcdb3 with in-flight modifications) and its
`_build` was removed. `GGEN_IGNITER_DIR` alone is no longer sufficient; the sibling
needs one `mix compile` (one-build fix, cross-repo, coordinator-level).

### 2.2 semantic_drive_anchor: failure mode changed — mu_on_O no longer observable

Same sibling drift, different presentation. The live-anchor describe block's setup
crashes before the kernel is ever invoked:

- Setup line (test/xaas/ultracode/semantic_drive_anchor_test.exs:171):

```elixir
{_, 0} = System.cmd("cp", ["-cRp", Path.join(@ggen_dir, "_build/test"), build])
```

- With no sibling `_build/test`, `cp` exits 1 (stderr, verbatim, printed twice,
  once per live test): `cp: /Users/sac/ggen_igniter/_build/test: No such file or directory`
- Both live tests fail identically in setup:

```
** (MatchError) no match of right hand side value:

    {"", 1}

stacktrace:
  test/xaas/ultracode/semantic_drive_anchor_test.exs:171: Xaas.Ultracode.SemanticDriveAnchorTest.__ex_unit_setup_0_0/1
```

- The two failing tests: "anchor/1 re-derives the recorded sJira hop from the
  committed work graph through mix semantic_jira.descriptor"
  (semantic_drive_anchor_test.exs:176) and "a work graph whose EP-A row was edited
  anchors to other digests: the committed hops are refused"
  (semantic_drive_anchor_test.exs:199).

Classification: **environment/cross-repo subject drift (missing sibling build),
NOT mu_on_O.** The W7 `mu_on_O` finding (`REFUSED(descriptor_refused: not_eligible
EP-A unknown_identity)` from `mix semantic_jira.descriptor` in the sibling) is
**unreachable-behind-setup-crash** in this rerun: execution never reaches the
kernel call. mu_on_O is neither confirmed nor refuted here. Once the sibling has
`_build/test` again, this suite re-exposes the kernel path and mu_on_O can be
re-asked. (Receipt-only rule: setup line 171 and the sibling were left untouched.)

### 2.3 v26_9_23_goal (17F) + xaas_stop_court (12F): one shared root cause — receipt schema v2 vs v1 court receipts

These two files ran for the first time since the vector-3 outage; all 29 failures
share one signature. The fleet R-schema at `~/.claude/dfcm/receipt.schema.json` is
now **v2** and requires four new root-level fields; its description (schema line 5,
verbatim): "v2: adds work_order_id, origin_authority, provider,
provider_execution_id (required), optional subject_before/subject_after digests,
identity.subject_digest for non-commit (sha256/blake3 pack) subjects riding on a
commit anchor, and the namespaced provider extension map (provider_ext.<provider>)".

Both suites validate court output through the real
`~/.claude/dfcm/validate_receipt.py` OS process (goal_test:25/106;
xaas_stop_court_test:28/169). Every court-emitted receipt is refused with the same
four lines, verbatim (goal_test failures 2 and 4, stop court failures — repeated
per receipt):

```
  <root>: 'work_order_id' is a required property
  <root>: 'origin_authority' is a required property
  <root>: 'provider' is a required property
  <root>: 'provider_execution_id' is a required property
```

Presentations of the same refusal:

- goal_test failure 2 (`test/sjira/v26_9_23_goal_test.exs:1405`, asserted at :1418,
  `assert vcode == 0, vout`): both fixture receipts REFUSED with the four lines.
- goal_test failure 4 (`test/sjira/v26_9_23_goal_test.exs:1916`, asserted at :1931,
  `assert {0, vout} = validate([gate_path, stop_path])`): both GC23-11.json and
  STOP-GC-26.9.23.json REFUSED with the four lines.
- goal_test failures 1 and 3 and stop court failures 1, 2 (court-level form): the
  stop court itself runs all gates to exit 0/75/3 but marks every gate
  `STANDING=NONE / RECEIPT=REFUSED`, order receipts `unlinked=:refused` /
  `unlinked=:missing`, and exits `STOP=false`. Verbatim (goal failure 1,
  test line 1115): gate row `GA     Core       NONE           0            0.0
  REFUSED            ran` and
  `order WO-A standing=NONE receipt=REFUSED digest=sha256:8b6a... unlinked=:refused
  from=option:.../order-receipts@9360a6e2`; expected `unlinked=:tuple_digest_mismatch`.

The stop court's own refusal follows the same validator contract: receipts missing
the v2 required fields cannot be ADMITTED, so gates fall to `NONE`/`REFUSED` and
STOP stays false — which cascades into the remaining goal/stop-court assertions
(exit-code contract tests at goal_test:999/1021, STOP=true tests at
xaas_stop_court_test:405/711/811, etc.).

Classification: **harness-schema v2 drift (cross-lane, harness-owned:
`~/.claude/dfcm/receipt.schema.json` + `validate_receipt.py`) vs. the court
receipt-writer still emitting v1 receipts.** Not an xaas-test defect and not an
environmental gate; coordinator-level repair is either (a) upgrade
`lib/mix/tasks/xaas.stop_court.ex` / court scripts to emit v2 fields, or (b) the
schema bump predates a pending court-side change elsewhere. No fix attempted here.

## 3. Standing

- UNCHANGED CONFIRMED (same counts as vector-3): r_projection 9/9,
  r_projection_consistency 18/18, yield 8/8 (autofde topology question closed:
  does not skip on missing autofde), successor 8/8.
- REGRESSED-LOOKING, root cause sibling-side: origin_authority 5 passed 5 skipped
  (missing `ggen_igniter/_build/test`); anchor 6/8 with setup MatchError at
  semantic_drive_anchor_test.exs:171 (same cause). **mu_on_O: UNREACHABLE this
  run** — not re-confirmed, not refuted.
- UNBLOCKED-AND-FAILING, one harness-schema root cause: v26_9_23_goal 20/37
  (17F), xaas_stop_court 7/19 (12F) — receipt schema v2 required fields vs v1
  court receipts.
- Raw captures: /tmp/goal_out.txt, /tmp/stop_out.txt, /tmp/anchor_out.txt.
- Nothing fixed, nothing committed, sibling untouched.
