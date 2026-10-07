# W121 — external_checkpoint_conflict Reachability

- Lane: W121
- Subject: see _LANES roster
- Date: 2026-10-06
- Note: backfilled by coordinator from lane completion report

## What landed

- `:external_checkpoint_conflict` proven reachable
  (actuation.ex:413-417: second checkpoint_external with diverging
  payload).
- Fixture: first checkpoint `{"construct":"inert","attempt":1}` then a
  diverging second; asserts
  `{:error, {:external_checkpoint_failed, {:external_checkpoint_conflict, key}}}`
  + first snapshot preserved.

## Gate output (verbatim as reported)

5/5 file total passed.

## Disclosures

None beyond the above.
