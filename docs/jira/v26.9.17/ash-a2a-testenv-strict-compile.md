# Ash-A2A Test-Env Strict Compile — close the latent 36-warning defect

## Summary

Fresh `MIX_ENV=test mix compile --force --warnings-as-errors` exits 1 on
ash_a2a `main` @ `801374a` with 36 warnings — test fixture domains not
present in `:ash_a2a, ash_domains` config (e.g.
`test/support/cancel_fixture.ex:53` `TenantedItemDomain`,
`auth_plug_fixture.ex:42` `EchoWithArgumentDomain`). The repo's own opt-out
pattern (`validate_config_inclusion?: false`, per
`test/support/fixture.ex:390-401,450`) exists but these fixtures omit it.
CI compiles dev only, so the defect is invisible to the repo's gates —
latent, above court bar, escalated rather than repaired during the boundary
wave.

## Status

Queued / Not Started (agent work, ash_a2a).

## Scope

1. Reproduce: fresh test-env compile, capture all 36 warnings (file:line).
2. Fix each fixture by the repo's established pattern
   (`validate_config_inclusion?: false` on the fixture domains) — no new
   opt-out mechanism, no config hacks.
3. Add the guard the repo lacks: a CI/test step or test that runs the
   test-env strict compile so the defect class cannot recur silently
   (follow the repo's own tripwire-test conventions).
4. Court: dev compile strict (must stay green), test-env compile strict
   (new green), full `mix test` (1912/0 modulo the DB-gated 8 invalid —
   `op-port-55432-free.md`).
5. Commit on `fix/ash-a2a-testenv-strict-compile` from `801374a`; never push.

## Key Invariant(s)

- Fixtures that SHOULD be in ash_domains config are not silenced — only the
  deliberately-unregistered ones get the typed opt-out (audit each of the 36).
- Dev-env strict compile must remain green throughout.

## Relationship to Existing Work

- `boundary-ash-a2a.md` falsifier 1 (the escalation record);
  `op-port-55432-free.md` (the other open slice of this boundary).

## Falsifiers / What Would Defeat This

- Silencing a fixture whose domain genuinely requires registration (hides a
  real misconfiguration).
- The guard step itself becomes red on unrelated fixture additions (guard
  must be fix-forward-friendly: failures point at the opt-out pattern).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | queued | ash_a2a main @ 801374a | test-env strict compile exit 1 (36 warnings); dev strict exit 0 | repro → per-fixture opt-outs → guard → court |
