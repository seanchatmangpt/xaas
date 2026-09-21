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
PARTIAL_ALIVE (2026-09-21): promotion constructed and verified at code head `191e7d5` (branch `sjira/sj-003`); the literal runnable check's first step, a root-level `ggen sync`, was not observed to complete (see `receipts/SJ-003.md`). Plugin-project `ggen sync run` exit 0, clean-room render identical to the checked-in projection, HANDWRITTEN.md Active rows 20 -> 18, `mix test` exit 0 (1346 tests, 0 failures). Not merged, not pushed.
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

## History

- 2026-09-21 | BLOCKED (superseded) | zcode default agent, `--mode edit`: `No permission client configured for Bash`, plus 25x provider 429 (code 1302); no product edits; record kept in `receipts/SJ-003-zcode-attempt.md`
- 2026-09-21 | PARTIAL_ALIVE | supervisor fallback construction in the same worktree: `191e7d5` (packs + ontology-lifted gate policy + HANDWRITTEN paydown); SA2A admit `rec-e088bcd4` (order) then `rec-ffcfcbb6` (construction claim) + replay verified; receipt `receipts/SJ-003.md`

## Description
Wave manufactured-ratio was 0% (docs/ultracode/PROGRESS.md). Templates/generator under priv/zcode_plugin and the lease/controller rows in HANDWRITTEN.md still name owner packs that do not render them. Promote the contract-clean templates into zcode-plugin-pack and admit ultracode-actuation-lease-pack; delete the corresponding HANDWRITTEN.md rows.

## Evidence
- HANDWRITTEN.md Active rows: lease.ex, execution_fabric_controller.ex, xaas.receipts.ex, priv/zcode_plugin/templates/*.tmpl
- PROGRESS.md: 'Ratio = 0%, honestly'

## Definition of done
- [ ] ggen renders the plugin files from the pack
- [ ] HANDWRITTEN.md has strictly fewer Active rows
- [ ] `git diff` of rendered output is empty on re-sync

Runnable check:

```sh
cd ~/xaas && ggen sync && git diff --exit-code && mix test
```

## Falsifiers
- a rendered file differs from the checked-in one
- HANDWRITTEN.md row removed while the file is still hand-edited
