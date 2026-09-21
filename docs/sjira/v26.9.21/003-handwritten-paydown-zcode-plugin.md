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
PARTIAL_ALIVE
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

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
