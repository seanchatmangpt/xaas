# W984dj3 — parse_dt/1 typed-refusal hardening (W984da residue)

Lane: W984dj3, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
branch `feat/playwright-surface`. No commit (coordinator owns integration).

## O/O*

W984da flagged: `parse_dt/1` in `lib/xaas/security.ex` used
`{:ok, dt, 0} = DateTime.from_iso8601(bin)` — a malformed ISO8601
`discovered_at`/`scan_date` string on ingest raised `MatchError`
(fail-open-class crash on the security family instead of a typed refusal).

## Fix shape

Matched the module's existing convention (`atomize/1`): unparseable input is
passed through unchanged so Ash's type system refuses it as a typed
validation error (`Ash.Error.Invalid` raised by `Ash.create!`), never a
MatchError. `lib/xaas/security.ex` `parse_dt/1` binary clause is now a
`case`:

- `{:ok, dt, _offset} -> dt` (also fixes the latent offset≠0 MatchError)
- `{:error, _reason} -> bin` — pass-through to the `utc_datetime` cast,
  typed refusal downstream

No changes to `finding.ex` needed; the ingest path refusal convention was
already the atomize-style pass-through.

## Court leg appended

`test/xaas/security/finding_lifecycle_depth_test.exs` test 6
(W984dj3): ingest a finding with `"discovered_at" => "not-a-timestamp"`
→ asserts `Ash.Error.Invalid` raised, zero `Finding` rows and zero
`Posture` rows leaked. Kills reversion of parse_dt to the bare match.

## Verification (real tails)

Fresh lane build root `_build-laneW984dj3`, pinned asdf toolchain:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dj3 \
  mix test test/xaas/security/finding_lifecycle_depth_test.exs \
           test/xaas/security/security_test.exs
# Running ExUnit with seed: 707574, max_cases: 32
# ..........  /  Finished in 1.0 seconds
# 10 passed, 0 failures
# exited with code 0
```

(Dep-compile logs showed pre-existing Grafana/PromEx nxdomain upload
warnings — environment noise, unrelated, both runs still exit 0.)

## Standing

ALIVE for this slice: fix executed on the exact subject, depth court +
security suite green fresh-root, typed-refusal leg witnessed firing.
Files touched: `lib/xaas/security.ex`,
`test/xaas/security/finding_lifecycle_depth_test.exs`, this receipt.

## Cleanup

`_build-laneW984dj3` deletion was permission-denied in this lane — left on
disk for coordinator cleanup at integration (fanout cleanup law).

## Falsifiers (open)

- Revert parse_dt to `{:ok, dt, 0} = ...` → test 6 must fail (witnessed
  design, not yet mutation-run).
- Offset≠0 ISO8601 (`"+01:00"`) now parses instead of crashing — no
  dedicated leg; covered indirectly by the case-clause shape.
