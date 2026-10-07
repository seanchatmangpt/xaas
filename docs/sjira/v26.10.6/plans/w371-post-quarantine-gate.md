# W371 — post-quarantine gate (OS-13 stray installer files)

Subject: /Users/sac/ash_surface (canonical checkout, unmodified)
Quarantine: /tmp/os13-quarantine-20261006-165326

## Sanity
`ls /Users/sac/ash_surface/lib/` → `ash_surface  ash_surface.ex  mix` —
`audit_trail/` and `notification_extension/` absent.
`lib/mix/tasks/` install tasks: only `ash_surface.install.ex`.

## Mix slice
Command:
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/ash_surface/_build-laneW371 mix test test/ash_surface/a2a_bridge_test.exs test/conformance test/ash_surface/standing_evidence_adversarial_test.exs test/ash_surface/health_http_mapping_test.exs`

Real tail:
```
.............................
Finished in 0.6 seconds (0.5s async, 0.02s sync)
Result: 36 passed
```
Expected 36/0 → observed 36/0.

## npm gate
Command: `npm test`

Real tail (last run, grep of counters):
```
ℹ tests 371
ℹ pass 367
ℹ fail 0
```
Expected 367/0 → observed 367 pass / 0 fail (371 total incl. 4 skipped).

## Cleanup
`rm -rf /Users/sac/ash_surface/_build-laneW371` — DENIED by permission system.
Build root left on disk: `/Users/sac/ash_surface/_build-laneW371`.

## Verdict
**QUARANTINE-CLEAN** — no failures; no failure references quarantined modules
(audit_trail, notification_extension, *_install.ex); no stray dependency.
