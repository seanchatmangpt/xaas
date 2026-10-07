# W938 — Dead-Branch Register Receipt

Lane W938, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`. No commit (per lane
contract). No build root used.

## What was registered

One typed row appended to `w859-typed-gap-register.md` (after the 49.3 row):

> | dead-branch/contract-drift: `format_actuation`'s `maybe_refusal/2` `[:refused, :failed]`
> clause is DEAD on the admitted fabric path — kernel refusals normalize to admit-time tool
> errors and OK envelopes carry only `:succeeded`/`:replayed`, so W844's quiescent `refusal`
> surfacing was wired to an unreachable branch; W866's courts fence it. Disposition options:
> delete the dead branch, or leave fenced by W866's courts until the kernel contract changes
> | w866-refusal-court.md (key finding); registered by w938-dead-branch-register.md
> | lib/xaas_web/controllers/execution_fabric_controller.ex:752-755
> | OPEN | w866-refusal-court.md |

## Verification

- Code re-read (not transcribed from W866's receipt): `lib/xaas_web/controllers/execution_fabric_controller.ex`
  — `format_actuation/2` calls `maybe_refusal/2` only under `opts[:quiescent?]`; the refusal
  clause matches `envelope.status in [:refused, :failed]` (lines 752-755).
- W866 finding confirmed per its receipt: on the admitted fabric path, kernel refusals
  normalize to admit-time tool errors and OK envelopes carry only `:succeeded`/`:replayed` —
  so the `[:refused, :failed]` clause is unreachable there; W866's courts fence the gap.
- Totals recomputed and grep-verified:

```text
$ grep -c '^| ' w859-typed-gap-register.md        # 44 (1 header + 43 data rows)
$ grep -c '| OPEN |' ...                          # 36
$ grep -c '| REPAIRED |' ...                      # 5
$ grep -c '| TYPED-OPEN |' ...                    # 2
36 + 5 + 2 = 43
```

Register totals section updated to **43 rows (36 OPEN + 5 REPAIRED + 2 TYPED-OPEN)**, OPEN list
extended with the W866/W938 dead-branch row.

## Standing

- Register row: OPEN (no repairing receipt; docketed with disposition options: delete the dead
  branch, or keep fenced by W866's courts until the kernel contract changes).
- This receipt: register-write only — no lib/ code touched, no commit, no build root.
