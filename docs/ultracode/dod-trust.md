# Ultracode DoD trust — falsifier probes and the suite health court

**Version:** v26.9.21 (track T4, branch `auto/t4-dod-trust`)
**Standing:** PARTIAL_ALIVE. The mechanisms below are ALIVE against real git repos and real
`/bin/sh` suites in `test/xaas/ultracode/{probes,verifier_probes,suite_health,order_probes,
dod_trust_wiring}_test.exs`. No real suite (`aps-dod`, `nounverb-dod`, `eds-dod`, `spr-dod`)
declares `probes`/`health` yet: that needs witnessed green/red refs in the registered clones
(see "What is not declared").

Until now "done" meant the order's own DoD command passed. With no human in the loop, the DoD
command itself has to be trustworthy: a suite that cannot fail (`exit 0`) or that drifted (wrong
toolchain, stale fixture) turns every `alive` into noise. Two machine courts replace the human
judgement "is this DoD any good?":

| court | question | where | verdict when it fails |
|---|---|---|---|
| falsifier probes | can this DoD fail on a tree that is known broken? | `Verifier.run/2` | `error`, `refusal: "vacuous_dod"` |
| suite health | does this suite still pass green and fail red? | `SuiteHealth`, `mix xaas.ultracode.suite_health` | suite quarantined, `refusal: "suite_unhealthy"` |

Both refuse with an `error` verdict, which `Lease.close/4` maps to `:partial_alive`; nothing here
can seal `:alive` (`AliveRequiresCourt` needs `fabric_verifier.status == "pass"`).

## 1. Falsifier probes

A probe is a named mutation given as data (`Xaas.Ultracode.Probes`): `replace`, `delete_line`,
`delete_file`, `truncate` (file, literal pattern, replacement) or `revert_commit` (a commit).
`Verifier.run/2` applies each probe to a scratch clone of the exact head under test, reruns the
suite's own steps there, and requires the rerun to FAIL.

| probe rerun | probe verdict | run verdict |
|---|---|---|
| fails | `killed` | stands (`pass`) |
| passes | `survived` | `error`, `refusal: "vacuous_dod"`, reason `{:vacuous_dod, [ids]}` |
| times out / errors | `inconclusive` | `error`, `refusal: "probes_refused"` |
| cannot be applied (pattern absent, no-op, symlink path, revert conflict) | `unapplicable` | `error`, `refusal: "probes_refused"` |

Sources, all admitted by `Probes.admit/1` (unknown keys, `..`, absolute or `.git` paths refused):

1. the suite: `probes: [%{id: "wrong-answer", kind: "replace", file: "answer.txt", pattern: "42",
   replacement: "41"}]`; `require_probes: true` refuses a suite that declares none;
2. `ctx[:probes]` on the `Verifier.run/2` call;
3. the `probes` key of the run's `{ticket}` file, written by `Autonomic` from the Semantic Jira
   order (section 3). A `probes_error` key (an order whose block was invalid) is a typed refusal.

Probes run only after the real steps passed, never touch the real worktree (scratch clone and temp
dirs are removed; the existing head/clean-tree checks still bracket the run), and are recorded in
`result["probes"]` / `result["probe_summary"]`.

## 2. Suite health court

A suite that declares `health:` is measured against a known-green and a known-red fixture:

```elixir
health: %{
  repo: "/abs/clone",             # default: the registered repo naming this suite
  green_ref: "refs/tags/dod-green",
  red_ref: "refs/tags/dod-red",   # or red_mutation: %{kind: "replace", file: ..., ...}
  max_age_seconds: 86_400
}
```

`SuiteHealth.check/2` clones each fixture under the worktree root, runs the real `Verifier.run/2`
on it and records a sealed receipt (`config :xaas, :ultracode_suite_health_dir`, latest per suite
plus `history.ndjson`). Verdicts: `healthy`, `vacuous` (passed known-red), `green_failed` (drift),
`inconclusive`, `blocked` (court could not run: unresolvable ref/repo, no worktree root).

Quarantine is derived from the latest receipt only and fails closed: missing, tampered or
future-dated receipt, a suite edited since the check (binding digest over steps, env, health),
older than `max_age_seconds`, or any verdict other than `healthy`. A quarantined suite is refused
at Run admission (`suite_unhealthy:<reason>`, `Validations.VerifierSuiteRegistered`) and by
`Verifier.run/2`. There is no unquarantine command: the only exit is a new healthy receipt.
`SuiteHealth.sweep/1` re-checks quarantined suites and healthy ones past half their life, and
`Autonomic.suite_health_gate/1` runs it before every wave, stopping the wave with
`{:error, {:suite_unhealthy, [{suite, reason}]}}` if a suite is still quarantined. The
controller also stops re-dispatching an item whose verdict carried a typed DoD refusal
(`vacuous_dod`, `probes_refused`, `suite_unhealthy`): nothing a worker changes repairs it.

```sh
mix xaas.ultracode.suite_health             # re-check quarantined / soon-stale suites
mix xaas.ultracode.suite_health --force     # re-check every managed suite
mix xaas.ultracode.suite_health --status    # read-only standing
mix xaas.ultracode.suite_health --strict    # non-zero if any suite is unmanaged
```

Exit status is non-zero while any managed suite is quarantined, so a cron/launchd wrapper pages on
drift. Suites without a `health` block are `unmanaged`: never quarantined, listed as such.

## 3. Order falsifiers as machine probes

`Xaas.Ultracode.OrderProbes` reads a Semantic Jira order's JSON front matter (`acceptance`,
`falsifiers`; the admitted field set is not widened) and a fenced block in the body:

````markdown
```xaas-probes
[{"kind": "replace", "file": "lib/x/digest.ex", "pattern": "digest_matches?(",
  "replacement": "always_true?(", "falsifier": 0}]
```
````

Each probe names the falsifier (or acceptance entry) it stands for, by index or exact text; an
anchor that matches nothing, or no anchor at all, is refused. `unprobed_falsifiers` reports the
falsifiers with no probe and `require_coverage/1` turns that into a refusal. The `Sensing`
`jira_dir` profile puts `probes` (or `probes_error`) on the item; `Autonomic` writes them into the
ticket; the fabric verifier reads them back. The worker supplies none of it.

## What is not declared

- No shipped suite has `probes`, `require_probes` or `health` yet. Declaring `health` on a real
  suite needs green and red refs witnessed in its clone (`~/xaas-worktrees/repos/<alias>`); an
  undeclared-but-quarantined suite would stop that repo's waves, so this is deliberately not
  guessed. `--strict` lists the gap.
- None of the nine `docs/sjira/v26.9.21` orders has a `xaas-probes` block yet; their falsifiers are
  prose (`OrderProbes.read/1` lists them as `unprobed_falsifiers`).
- Probe reruns multiply suite cost by the probe count; suites with slow steps should keep probes
  few and targeted (max 32 per run).

## See also

- `docs/ultracode/multi-repo-run.md` — registered repos, suites and sensing profiles.
- `docs/ultracode/eight-hour-run.md` — the wave/campaign budget these gates sit in front of.
- `lib/xaas/ultracode/verifier.ex` — threat model and result contract.
