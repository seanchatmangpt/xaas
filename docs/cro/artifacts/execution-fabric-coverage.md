# Execution-Fabric Controller Coverage

Coverage story for `lib/xaas_web/controllers/execution_fabric_controller.ex`, consolidated
from 4 receipts (lane W970b, 2026-10-07).
- **Dispatch surface**: 10 verbs on `POST /internal-api/execution/mcp`, 9 lease-gated,
  `claim_next` the only non-lease verb (w749-runtime-contract-refresh.md, claim 2).
- **Deepening courts**: typed-refusal lattice, actuation boundary (real `ActuationIntent` +
  receipt + provider mutation; unregistered pair → typed `unregistered_actuation`), auth
  floor — 15 passed, mock gate clean (w745-execution-fabric-deepening.md).
- **Quiescent tie + envelope surfacing**: actuate formats quiescent halts additively
  (`target`/`already_stopped`/`refusal`), no field leak on generic actuations;
  mutation-verified (revert → 5/6, restored → 6/6) (w844-quiescent-envelope.md, courts e/f).
- **Dead-branch disposition**: `format_actuation`'s `maybe_refusal/2` `[:refused, :failed]`
  clause (+ fallback + `refusal_code/1`) deleted as unreachable — kernel refusals normalize
  to admit-time tool errors, OK envelopes carry only `:succeeded`/`:replayed`
  (w970-dead-branch-disposition.md; registered w938-dead-branch-register.md).
- **Live fence**: kernel-refused quiescent attempt (admit-time `idempotency_conflict`, one
  intent row, receipt stays `:succeeded`) and malformed stop authority
  (`REFUSED_STOP_AUTHORITY` before admission, no intent row) — W866's courts (g)/(h) remain
  the tripwire if the kernel OK-envelope contract changes (w866-refusal-court.md).
Standing: court suites cited from their own receipts; not re-run (no build root).
