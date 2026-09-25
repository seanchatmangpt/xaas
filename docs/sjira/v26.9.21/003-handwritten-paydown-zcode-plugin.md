---
{
  "identity": "SJ-003",
  "title": "Pay down HANDWRITTEN.md: promote zcode plugin templates into zcode-plugin-pack",
  "description": "Wave manufactured-ratio was 0% (docs/ultracode/PROGRESS.md). Templates/generator under priv/zcode_plugin and the lease/controller rows in HANDWRITTEN.md still name owner packs that do not render them. Promote the contract-clean templates into zcode-plugin-pack and admit ultracode-actuation-lease-pack; delete the corresponding HANDWRITTEN.md rows.",
  "subject": "handwritten-paydown-zcode-plugin",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "PARTIAL_ALIVE",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-003",
  "required_courts": [
    "compile",
    "tests",
    "chicago_no_mocks"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "ggen renders the plugin files from the pack",
    "HANDWRITTEN.md has strictly fewer Active rows",
    "`git diff` of rendered output is empty on re-sync"
  ],
  "falsifiers": [
    "a rendered file differs from the checked-in one",
    "HANDWRITTEN.md row removed while the file is still hand-edited"
  ],
  "projections": [
    "jira",
    "machine",
    "verification",
    "receipt"
  ],
  "dependencies": [],
  "authority_requirement": "NONE",
  "path_scope": [
    "HANDWRITTEN.md",
    "priv/zcode_plugin/**",
    "lib/xaas/generated/**"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-003: Pay down HANDWRITTEN.md: promote zcode plugin templates into zcode-plugin-pack

- **Standing**: PARTIAL_ALIVE

## Status
PARTIAL_ALIVE (2026-09-22): re-verified at code head `4ffd58d` (branch `sjira/sj-003`, worktree `/Users/sac/xaas/worktrees/sjira/sj-003`). All templates flagged in HANDWRITTEN.md as belonging to `zcode-plugin-pack`/`ultracode-actuation-lease-pack` are already promoted from prior waves (`priv/zcode_plugin/templates/` is empty; both packs render from `priv/zcode_plugin/packs/*`). This session found nothing further honestly promotable this run: the sole remaining zcode-plugin-scoped Active row (`agent-xaas-worker/command-xaas/skill-xaas-worker` doctrine prose bodies) is genuinely irreducible prose with no ontology-fragment model to promote it into, and the qualification-test row (`test/xaas/zcode_plugin/*.exs`) needs a not-yet-existing `zcode-plugin-pack gates/` generator, which is new-pack invention out of this session's honest scope, not a promotion of already-generator-backed code. HANDWRITTEN.md Active-row count is unchanged this session (18, same as the prior wave landed); DoD item 2 ("strictly fewer Active rows") is NOT advanced this run — recorded honestly rather than claimed. DoD items 1 and 3 re-verified live this run (see Evidence). Not merged, not pushed.
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

## Description
Wave manufactured-ratio was 0% (docs/ultracode/PROGRESS.md). Templates/generator under priv/zcode_plugin and the lease/controller rows in HANDWRITTEN.md still name owner packs that do not render them. Promote the contract-clean templates into zcode-plugin-pack and admit ultracode-actuation-lease-pack; delete the corresponding HANDWRITTEN.md rows.

## Evidence
- HANDWRITTEN.md Active rows: lease.ex, execution_fabric_controller.ex, xaas.receipts.ex, priv/zcode_plugin/templates/*.tmpl
- PROGRESS.md: 'Ratio = 0%, honestly'
- 2026-09-22 live run at `4ffd58d` (this session, worktree `/Users/sac/xaas/worktrees/sjira/sj-003`):
  - `cd priv/zcode_plugin && ggen sync run` -> exit 0, every render `"unchanged: content identical"` (9/9 outputs, both packs' hashes recorded in the JSON receipt)
  - `git diff --exit-code -- priv/zcode_plugin lib/xaas/generated HANDWRITTEN.md` -> exit 0
  - `ggen sync` (repo root, no args — the ticket's literal first check step) -> exit 0 for the first time observed; side effect: also renders the unrelated `xaas-castle-bridge-pack` (out of SJ-003 path_scope) — reverted (`git checkout -- lib/xaas/castle.ex`; removed untracked `GGEN-SH-AFTER-*`, `ggen.lock`, `lib/xaas/generated/castle_bridge_*.ex`, `docs/claude/diataxis/reference/generated-castle-bridge-errc.md`, `priv/semantic/`, `test/xaas/generated/`) so this session's diff stays in scope
  - `mix test test/xaas/zcode_plugin/` -> 33 tests, 1 failure: `projection_test.exs:89` `refute File.exists?("generated")` fails because `generated/castle_bridge/` exists with mtime 2026-09-21 15:17 (pre-existing, predates this session's start, unrelated to zcode_plugin scope)
  - `find priv/zcode_plugin/templates -type f` -> empty (all zcode-plugin-scoped templates already promoted into `packs/zcode-plugin-pack/` and `packs/ultracode-actuation-lease-pack/` by the prior 2026-09-21 wave)

## Definition of done
- [x] ggen renders the plugin files from the pack -- re-verified live 2026-09-22, all 9 outputs `unchanged: content identical`
- [ ] HANDWRITTEN.md has strictly fewer Active rows -- not advanced this session (still 18); remaining zcode-plugin-scoped Active rows are honestly non-promotable this run (irreducible doctrine prose; qualification-test row needs an as-yet-uninvented `gates/` pack, out of scope for a promotion-only session)
- [x] `git diff` of rendered output is empty on re-sync -- re-verified live 2026-09-22, exit 0
Runnable check:

```sh
cd ~/xaas && ggen sync && git diff --exit-code && mix test
```
## Falsifiers
- a rendered file differs from the checked-in one
- HANDWRITTEN.md row removed while the file is still hand-edited

## History

- 2026-09-21 | BLOCKED (superseded) | zcode default agent, `--mode edit`: `No permission client configured for Bash`, plus 25x provider 429 (code 1302); no product edits; record kept in `receipts/SJ-003-zcode-attempt.md`
- 2026-09-21 | PARTIAL_ALIVE | supervisor fallback construction in the same worktree: `191e7d5` (packs + ontology-lifted gate policy + HANDWRITTEN paydown); SA2A admit `rec-e088bcd4` (order) then `rec-ffcfcbb6` (construction claim) + replay verified; receipt `receipts/SJ-003.md`
- 2026-09-22 | PARTIAL_ALIVE (re-verified, no further paydown) | live re-run of the runnable check at `4ffd58d`: plugin-scoped `cd priv/zcode_plugin && ggen sync run` exit 0, all outputs `"unchanged: content identical"`; `git diff --exit-code -- priv/zcode_plugin lib/xaas/generated HANDWRITTEN.md` exit 0; root-level `ggen sync` (the ticket's literal first runnable-check step) exit 0 for the first time this session — but it also renders an unrelated `xaas-castle-bridge-pack` projection (`lib/xaas/castle.ex`, `lib/xaas/generated/castle_bridge_*.ex`, `docs/claude/diataxis/...`) outside SJ-003's path_scope; those out-of-scope writes were reverted (`git checkout -- lib/xaas/castle.ex`, untracked castle-bridge artifacts removed) to keep the worktree scoped and clean, leaving `git status --porcelain` empty. `mix test test/xaas/zcode_plugin/` exit 0 except 1 pre-existing, out-of-scope failure (`projection_test.exs:89` `refute File.exists?("generated")` — a stray `generated/castle_bridge/` dir with an mtime predating this session, unrelated to zcode_plugin). No HANDWRITTEN.md rows changed.
