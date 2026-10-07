# W385 — A2A v1 Conformance Court Receipt (Y-primitive, one-command machine report)

## Subject
- Repo: /Users/sac/ash_a2a @ HEAD `07180bd3` (branch `feat/tck-vuln-hardening`), read-only + task run
- Task: `mix ash_a2a.v1_conformance_report` (`lib/mix/tasks/ash_a2a.v1_conformance_report.ex`)
- Date: 2026-10-07 (generated_at `2026-10-07T00:23:12.430147Z`), Elixir 1.20.4

## Command (documented offline form; no server bootstrap required)
```bash
cd /Users/sac/ash_a2a && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  MIX_BUILD_ROOT=/Users/sac/ash_a2a/_build-laneW385 \
  mix ash_a2a.v1_conformance_report --out /tmp/w385-v1-conformance.json
# EXIT=0
```

## Real output block
```
A2A v1.0 conformance courts selected: 26 of 26 (this is NOT the official A2A TCK; see docs/reference/a2a-v1-conformance.md)
machine report written to /tmp/w385-v1-conformance.json
totals: 26 PASS, 0 FAIL, 26 total (report task: exit 0 regardless; the gate is totals.fail == 0)
```

JSON totals: `{"total": 26, "pass": 26, "fail": 0}`; 311 individual tests passed across courts; every court `verdict: "PASS"`, zero missing-on-disk courts.

## Verdict
CONFORMANT 26/26 (100%) at HEAD 07180bd3 against the pinned in-repo court corpus —
one-command court (primitive Y) ALIVE at current pin. Feeds w366-sibling re-pin
decision. Standing caveat, per the task's own moduledoc and
`docs/reference/a2a-v1-conformance.md`: this is the in-repo pinned court corpus,
NOT the official A2A TCK; TCK-certified remains UNSUPPORTED.

## Transport failures / notes
- First run was killed at the background time limit during fresh-lane dep compile
  (cold `MIX_BUILD_ROOT`); rerun on the warm build root completed in ~5 min.
- Cleanup: `rm -rf /Users/sac/ash_a2a/_build-laneW385` was DENIED by the
  permission system (twice). Build root left on disk — DENIED(cleanup), ~lane
  build root lease NOT released.
- Full JSON report preserved at `/tmp/w385-v1-conformance.json`; raw stdout at
  `/tmp/w385-conformance-stdout2.log`.
