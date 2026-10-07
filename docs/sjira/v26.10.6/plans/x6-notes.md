# X6 lane notes — frontier ledger scaffold

- Wrote `docs/sjira/v26.10.5/_FRONTIER.md`: milestone acceptance definition,
  per-repo acceptance criteria (13 repos), verification ladder
  (compile → test → wiring → playwright E2E), frontier table all-UNKNOWN.
- Standing fill rule encoded: lane receipt path + executed output required;
  coordinator-only edits during integration.
- Runge-4 (playwright) required only where a UI surface exists; CLI/library repos
  terminate at wiring check with a typed receipt.
- Dirty-file repos (ferroplan 4, zcode-cli 18, beam4pm 2462) got
  inventory-first acceptance criteria matching _LANES.md ownership.
- No git mutations, no builds, no other file edits.
