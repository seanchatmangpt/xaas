# AIRo Pin-Court Vocabulary Pin — lane W981j (2026-10-07)

Canonical AIRo 1.0 vocabulary identity, verified on this machine by real
commands, for use by every pin court in `airo-wiring-ledger.md`.

## Pin

- **content sha256**: `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`
- **local canonical source**: `/Users/sac/xaas/priv/semantic/airo/airo.ttl`
  (w600 vendor row; byte-identical copies listed in the ledger's
  cross-repo sha table).
- **upstream**: AIRo 1.0, `DelaramGlp/airo@6c67de4`, CC-BY-4.0.
- **verification executed (W981j, 2026-10-07)**:
  `shasum -a 256 priv/semantic/airo/airo.ttl` →
  `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469` (match).

## Git blob identity (xaas, working tree, uncommitted — coordinator owns commits)

- `git rev-parse HEAD:priv/semantic/airo/airo.ttl` at verification time →
  `c4274ab083f7cff1fe18f03e7a18e79d752ecf93` (blob sha, environment identity).
- The pin identity used by courts is the **content sha256** above, not the
  blob sha: consumer repos vendor the bytes, not xaas git objects.

## Court usage

`test/xaas/airo/airo_pin_court_test.exs` asserts, per ledger row:
cited paths exist at the sibling checkout, falsifier names a concrete
`.ttl` artifact path, HEAD matches the ledger SHA, and this file carries
the exact pinned content sha256. Unknown-sha rows get
`REFUSED(unverifiable-sha)`, never a guess.
