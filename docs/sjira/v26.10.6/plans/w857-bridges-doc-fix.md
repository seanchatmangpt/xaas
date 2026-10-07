# W857 — External capability bridges doc correction — receipt

**Lane**: W857, xaas v26.10.6 campaign. Canonical checkout `/Users/sac/xaas`,
branch `feat/playwright-surface`, HEAD `a0723bf6`. No commit (coordinator owns
transitions). **Files written**: `docs/claude/diataxis/explanation/architecture-overview.md`
(External capability bridges section only) + this receipt. No lib/test changes, no build root.

## Source facts (read before editing)

- `lib/xaas/bridges/registry.ex` — 5 bridge rows `pplan, graphlaw, ex4pm, sa2a,
  ferroplan` (`registry.ex:61-95`: `state: :bridge`, standing `"UNKNOWN"`,
  `capability: {:bridge, Module}`) + 5 absences `beam4pm, graphlaw_rust,
  affidavit_cli, ash_r2rml, wasm4pm` (`registry.ex:15-31, 96-104`:
  `state: :unsupported`, standing `"UNSUPPORTED"`, `capability: {:unsupported,
  reason}`). Export surface is exactly `all/0`, `ids/0`, `absences/0`
  (`registry.ex:33-59`) — no arity>0 function.
- `docs/sjira/v26.10.6/plans/w767-registry-deepening.md` — court (a) pins the
  exact 5+5 row set (14/14 ExUnit, real run); court (d) pins the
  standing-never-silent-upgrade property (structural, 0-arity projections,
  standing changes only via recompile); gymact/ash_a2a rows recorded
  `UNSUPPORTED(absent-from-registry)`.

## Per-claim changes

1. **Registry inventory** — was: "three read/admit-shaped edges … all registered
   in `Xaas.Bridges.Registry` with `state: :bridge` and standing UNKNOWN."
   Now: registry described as exactly 5 bridge rows + 5 typed absences (10
   rows), with both row shapes, citing W767 court (a). Evidence: the old text
   was false against `registry.ex` (no gymact/ash_a2a rows exist; pplan/
   graphlaw/ex4pm/sa2a were unnamed).
2. **Mechanism distinction** — section now names three mechanisms: registry
   rows vs direct adapters (GymactSurface) vs wire transports (`POST /a2a/v1`
   via `V1TransportPlug`). The gymact and AshA2A bullets are re-labeled as
   *not* registry rows, per W767 `UNSUPPORTED(absent-from-registry)`.
   Evidence: `lib/xaas/operations/gymact_surface.ex` and
   `lib/xaas_web/a2a/v1_transport_plug.ex` are not referenced anywhere in
   `registry.ex`.
3. **Standing-never-silent-upgrade property** — added to the registry bullet:
   export surface is exactly the 0-arity projections, no code path accepts a
   receipt/standing argument, standing changes only by recompiling the literal
   entries (admitted code transition, never runtime upgrade). Cites W767
   court (d). Evidence: `registry.ex:33-59` (only 0-arity defs) and W767
   receipt court (c)/(d).

Unchanged: ferroplan, gymact, AshA2A technical detail bullets (mechanism
content verified accurate against the live section; only their framing lines
changed), and every other cross-cutting-mechanisms bullet.

## Standing

- Doc claims now match the live registry at HEAD `a0723bf6`: **ALIVE** for the
  inventory/mechanism/property claims (each grounded to `registry.ex` line
  numbers and the W767 executed court).
- Remaining UNKNOWN: none introduced; W767's PARTIAL_ALIVE court remains the
  standing authority for the registry surface itself.

## Replay

```
sed -n '61,95p' /Users/sac/xaas/lib/xaas/bridges/registry.ex   # 5 bridge rows
sed -n '15,31p' /Users/sac/xaas/lib/xaas/bridges/registry.ex   # 5 absences
grep -n 'Registry row\|registry row\|not a registry row' \
  /Users/sac/xaas/docs/claude/diataxis/explanation/architecture-overview.md
cat /Users/sac/xaas/docs/sjira/v26.10.6/plans/w767-registry-deepening.md
```
