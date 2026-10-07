# W970 — Dead-Branch Disposition Receipt

Lane W970, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`. No commit (per lane
contract; coordinator owns integration).

## Disposition

**DELETED.** `format_actuation`'s `maybe_refusal/2` `[:refused, :failed]` clause (plus its
fallback clause and `refusal_code/1`, both dead by the same proof) is removed from
`lib/xaas_web/controllers/execution_fabric_controller.ex`, replaced by a comment citing
W938/W859 + W866: `Xaas.Actuation.run/4` normalizes `:refused`/`:failed` envelopes to
`{:error, error}` (admit-time tool errors), so an OK envelope carries only
`:succeeded`/`:replayed` and the `refusal` key was unreachable. W866's courts (g)/(h) in
`test/xaas_web/quiescent_fabric_tie_test.exs` remain the fence if the kernel OK-envelope
contract ever changes.

Dual citation: w866-refusal-court.md (dead-branch proof + fence courts) and
w938-dead-branch-register.md / w859-typed-gap-register.md (register row, dead-branch/contract-drift).

## Mutation rationale

The deletion is verified-safe by W866's proof: no reachable `:refused`/`:failed` envelope on
the admitted fabric path. The fence courts assert the reachable behavior unchanged.

## Deletion diff

```
@@ format_actuation/2 (lib/xaas_web/controllers/execution_fabric_controller.ex)
-      |> maybe_refusal(envelope)
     else
...
-  defp maybe_refusal(formatted, %{status: status} = envelope)
-       when status in [:refused, :failed] do
-    Map.put(formatted, :refusal, refusal_code(envelope.error))
-  end
-
-  defp maybe_refusal(formatted, _envelope), do: formatted
-  defp refusal_code(reason) when is_atom(reason), do: Atom.to_string(reason)
-  defp refusal_code(reason), do: inspect(reason)
```

Diff stat: `lib/xaas_web/controllers/execution_fabric_controller.ex` 28 lines changed;
`test/xaas_web/quiescent_fabric_tie_test.exs` 41 lines changed (+W970 fence court, comment
updates dual-citing w866+w970).

## Test extension (fence)

`test/xaas_web/quiescent_fabric_tie_test.exs`:

- (g) comment block updated: mapping noted as DELETED (W970), courts remain the contract tripwire.
- New W970 fence court: "quiescent OK envelopes (succeeded + replayed) carry no refusal key,
  W844 envelope fields intact after the maybe_refusal/2 deletion" — asserts `refusal` key
  absent on both OK envelopes and `target`/`already_stopped` fields unchanged.

## Verification (real tails)

Two consecutive runs, `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW970`,
`mix test test/xaas_web/quiescent_fabric_tie_test.exs test/xaas_web/execution_fabric_deepening_test.exs`:

```
$ mix test ... (run 1)
Result: 25 passed
$ mix test ... (run 2)
Result: 25 passed
```

(Interleaved `[Reactor.Audit] ... idempotency_conflict` log lines are the W866 conflict
court's expected error-path output, not failures.) The W844 quiescent-envelope courts
(`target`/`already_stopped`) live inside the tie suite and are green — those fields are on
the OK path, unaffected by the deletion.

One intermediate red was session-introduced and repaired in-lane: the new fence court
initially called `halt_key()` twice (different keys), so the replay assert saw
`succeeded`; fixed by binding the key once. Single green run after repair, then the ×2.

## Environment / transport notes

- First lane compile failed in `lib/xaas/governance/checks/freeze_window_active.ex`
  (`misplaced operator ^org_id`) — an untracked file being written concurrently by another
  lane (~4 min old at failure). Not session-introduced by W970; that lane repaired it
  (mtime moved, compile then clean, "Generated xaas app") and both test runs followed.
- Register flip (W938/w859 row OPEN → REPAIRED): NOT performed. The register file
  (`w859-typed-gap-register.md`) mtime was 66 seconds old at lane start — a sweep appeared
  mid-flight. Disposition is recorded here only; next sweep flips the row.

## Standing

- `lib/xaas_web/controllers/execution_fabric_controller.ex`: ALIVE (deletion verified on
  real fabric+tie suites ×2, 25/25 both).
- `test/xaas_web/quiescent_fabric_tie_test.exs`: ALIVE (extended fence court green ×2).
- W938/w859 register row: remains OPEN on disk; disposition REPAIRED here, flip deferred
  to next sweep (sweep mid-flight detected via mtime).
- `_build-laneW970`: delete attempted, denied by permission system — left for coordinator
  per lane contract fallback.
