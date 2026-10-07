# W103 Local Prod-Compile Receipt — v26.10.6 Convergence

- Lane: W103 (integration), repo `/Users/sac/xaas`, branch `feat/playwright-surface`, changed tree (uncommitted), 2026-10-06
- Command (verbatim, per W84 court):

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=prod mix compile --force --warnings-as-errors 2>&1 | tail -15
```

- Toolchain: asdf shims first on PATH. Elixir 1.20.2 / Erlang/OTP 28 (erts-16.4.0.2), matching `.tool-versions` pin.
- Full raw log retained at `/tmp/w103_prod_compile.log` (87 KB).

## Exit code

Verbatim end of run log:

```
Compilation failed due to warnings while using the --warnings-as-errors option
EXIT_CODE=1
```

**Exit code: 1** — compile FAILED under `--warnings-as-errors`. No hard compile errors
were emitted; the failure is entirely warning-driven.

## Warning totals

132 warnings total: **16 app-code (xaas)** and **116 dep-side** across 24 dependency apps.

## App-code (xaas) warnings — 16

### A. Spark DslError × 12 — identities missing `pre_check_with` (app-code)

```
warning: ** (Spark.Error.DslError) The data layer does not support native checking of identities.
Must specify the `pre_check_with` option.
```

The court output names only the identity, not the owning module. Tree grep correlation
(classification as app-code is verbatim from the log; per-resource attribution is inferred):

| identity | errors | declaring files in lib/ |
|---|---|---|
| `unique_slug` | 5 | conference event/track/speaker/sponsor/session, marketplace provider, library school, accounts org (8 declarers) |
| `unique_name` | 2 | (not uniquely resolvable from output) |
| `unique_task_id` | 1 | `lib/xaas/a2a/task.ex:46` |
| `unique_email` | 1 | `lib/xaas/conference/attendee.ex:50` (also `lib/xaas/accounts/user.ex:345`) |
| `unique_code` | 1 | `lib/xaas/igniter/refusal_code.ex:39` |
| `unique_pack_name` | 1 | `lib/xaas/igniter/pack_manifest.ex:35` |
| `unique_attendee_session` | 1 | `lib/xaas/conference/registration.ex:49` |

### B. Individual compiler warnings — 4

| # | location | warning |
|---|---|---|
| 1 | `lib/mix/tasks/xaas.release_snapshot.verify.ex:48:7` (`run/1`) | clauses with the same name and arity should be grouped together; `def run/1` previously defined at line 18 |
| 2 | `lib/xaas_web/plugs/stripe_raw_body_reader.ex:23:22` (`read_body/2`) | variable `conn` is unused |
| 3 | `lib/xaas/actuation.ex:388:33` (`Xaas.Actuation.Kernel.actuate/2`) | `Exception.blame?/1` is undefined or private (did you mean `blame/3` / `blame_mfa/3`) |
| 4 | `lib/xaas/bridges/ferroplan.ex:366` (`Xaas.Bridges.Ferroplan.call_abi/2`) | the following clause will never match — type warning on `{store, pid} when store != nil and pid != nil` |

## Dep-side warnings — 116 across 24 apps

Disclosed pre-existing; the repo diff does not touch these apps. Per-app counts (derived
from `==> app` section boundaries in the same log):

ash_a2a 20 · ash_json_api 11 · ash_authentication 11 · ex4pm 9 · grpc 8 (all
`:gun.* is not available` xref) · ash_r2rml 7 · ash_money 7 · ash_iam 7 · ash_phoenix 6 ·
ggen_igniter 5 · ash_sql 5 · petal_components 4 · prom_ex 3 · ash_paper_trail 3 ·
ash_authentication_phoenix 2 · req_llm 1 · phoenix_live_dashboard 1 · opentelemetry_ash 1 ·
ash_pplan 1 (`xref: [exclude: ...]` deprecation) · ash_events 1 · ash_affidavit 1
(`@envelope_domain_tag` set but never used — disclosed pre-existing) · ash_admin 1 ·
ash 1.

## Verdict

- Result: **FAILED (warnings-as-errors), exit code 1.**
- 16 app-code warnings on the current changed tree: 12 Ash identity `pre_check_with`
  DslErrors + 4 individual compiler warnings (locations in table B).
- 116 dep-side warnings, disclosed pre-existing.
- No fixes applied, no git operations performed.
- Replay: the exact command above; raw log `/tmp/w103_prod_compile.log`.
