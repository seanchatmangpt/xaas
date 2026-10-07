# W707 — gymact seal fix (lane receipt)

- **Lane**: W707, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface`, base HEAD `a0723bf6` (uncommitted lane:
  no commit per dispatch).
- **Subject**: `lib/xaas/operations/gymact_surface.ex` (modified),
  `test/xaas/operations/gymact_surface_deepening_test.exs` (extended),
  this receipt. Handwritten; no generator surface applies.
- **Standing**: ALIVE (lane-scoped, uncommitted) — 20/20 real-test pass on
  the exact working tree (`mix test gymact_surface_test.exs
  gymact_surface_deepening_test.exs` → `20 passed`, base court includes a
  real uvicorn gymact subprocess).

## Before (W674 receipt, docs/sjira/v26.10.6/plans/w674-gymact-deepening.md)

- **W674-GAP-1**: non-2xx remote → `GymactSurface.do_and_seal/2` handed
  `Xaas.Actuation.seal_external/2` the raw `{:gymact_http_error, status,
  body}` tuple; `json_safe/1` rendered it as a LIST, the `ActuationReceipt
  :seal` action rejected the `:error` map attribute
  (`InvalidAttribute{field: :error, message: "is invalid"}`), the whole
  seal transaction rolled back (`{:error, {:external_seal_failed,
  %Ash.Error.Invalid{}}}`), and no `:failed` receipt was ever recorded —
  the durable prepare survived (`intent :executing`, `receipt :prepared`)
  and the ledger never learned the DO failed.
- **W674-GAP-2**: `actuate/4` without `:episode_id`/`:cut` raised a raw
  `WithClauseError` from `Keyword.fetch/2` inside `do_and_seal/2`; the
  prepare survived unsealed, unrefused.

## After (fix, minimal)

`lib/xaas/operations/gymact_surface.ex` only — the `:seal` action and all
of `Xaas.Actuation` are untouched:

1. **GAP-1**: `do_and_seal/2` converts remote DO failures to json-safe
   typed maps before sealing:
   - `{:gymact_http_error, status, body}` →
     `{:error, %{class: :gymact_http_error, status: status, body: json_safe(body)}}`
   - `{:gymact_transport_error, exception}` →
     `{:error, %{class: :gymact_transport_error, message: Exception.message(exception)}}`
   `Kernel.seal` then durably records receipt+intent `:failed` with the
   json-safe map. The seal action is not relaxed; the wire tuples from
   `request/4` (health/providers/etc.) are unchanged.
2. **GAP-2**: missing/empty `:episode_id` (non-binary) or `:cut`
   (non-map) now flow through `external_opt/2` → `Refusal.new/2` with the
   new closed atom codes `:episode_id_required` / `:cut_required`;
   `Kernel.seal` classifies the `Xaas.Actuation.Refusal` as policy
   `:refused` and durably records receipt+intent `:refused` with error
   `%{"refused" => code, "detail" => json_safe(detail)}`.
3. **Surfaced contract** (observed, not assumed): `Xaas.Actuation`'s
   `normalize_transaction_result/1` maps `:failed`/`:refused` sealed
   envelopes to `{:error, error}` — so `actuate/4` returns
   `{:error, %{class: ...}}` / `{:error, %Refusal{code: ...}}` exactly as
   the local `run/4` path surfaces failures. No new return shape invented.

## Regression courts (extended, W674's 9 kept green)

- `non-2xx remote is durably sealed :failed with a json-safe typed error
  map` — real Bandit 500 over real Req; asserts
  `{:error, %{class: :gymact_http_error, status: 500, body: %{"error" => "internal"}}}`,
  receipt `:failed` with error
  `%{"class" => "gymact_http_error", "status" => 500, "body" => %{"error" => "internal"}}`,
  `completed_at`, intent `:failed`, subject unmutated, exactly 1 receipt.
- `transport-level remote failure is durably sealed :failed ...` — real
  connection-refused (`http://127.0.0.1:1`); asserts the typed
  `:gymact_transport_error` error map and durable `:failed` states.
- `missing :episode_id is a typed :episode_id_required refusal, durably
  sealed :refused` — asserts
  `{:error, %Xaas.Actuation.Refusal{code: :episode_id_required}}`, receipt
  `:refused` with `%{"refused" => "episode_id_required", "detail" =>
  %{"opt" => "episode_id"}}`, intent `:refused`.
- `missing :cut is a typed :cut_required refusal, durably sealed :refused`.

**Mutation check** (fix reverted mentally, which assert kills it):

- GAP-1: revert `do_and_seal/2` to pass the raw tuple → `json_safe/1`
  renders a LIST, the `:seal` action rejects `:error`, the transaction
  rolls back and `actuate/4` returns
  `{:error, {:external_seal_failed, %Ash.Error.Invalid{}}}`. Killed twice:
  the `assert {:error, %{class: :gymact_http_error, status: 500, ...}}`
  pattern (match fails) AND `assert %...ActuationReceipt{status: :failed}`
  (receipt stays `:prepared`).
- GAP-1 (transport): revert the transport clause → same rollback; killed
  by `assert {:error, %{class: :gymact_transport_error, ...}}` and the
  durable `:failed` receipt assert.
- GAP-2: revert `external_opt/2` to `Keyword.fetch/2` → `actuate/4` RAISES
  `WithClauseError` instead of returning; killed by the
  `assert {:error, %Xaas.Actuation.Refusal{code: :episode_id_required}}`
  match (the test fails with an uncaught raise, and the durable
  `:refused` receipt asserts fail too — the prepare survives unsealed).

## Green tails (real output)

```
$ cd /Users/sac/xaas
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW707 \
    mix test test/xaas/operations/gymact_surface_deepening_test.exs
Finished in 1.1 seconds (0.00s async, 1.1s sync)
Result: 11 passed

$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW707 \
    mix test test/xaas/operations/gymact_surface_test.exs \
             test/xaas/operations/gymact_surface_deepening_test.exs
Finished in 13.6 seconds (0.00s async, 13.6s sync)
Result: 20 passed
```

(9 base courts incl. the real uvicorn gymact subprocess + 11 deepening =
W674's 9 kept green + 4 new; the two W674 gap courts were converted in
place from asserting the disclosed buggy contract to asserting the fixed
typed contract, preserving the 9-court structure.)

## Intermediate failure recorded (repair loop)

Run 1 (post-fix): 7/11 — the 4 new courts expected `{:ok, envelope}` with
`envelope.status == :failed/:refused`. Probe of `Kernel.seal/2` showed the
envelope IS returned as `{:ok, ...}`, but `normalize_transaction_result/1`
(actuation.ex:231) intentionally maps failed/refused envelopes to
`{:error, error}` — the platform contract for ALL callers. Courts were
corrected to the observed contract; no lib change was made to mask it.

## Replay / environment

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW707 \
  mix test test/xaas/operations/gymact_surface_test.exs \
           test/xaas/operations/gymact_surface_deepening_test.exs
```

Local Postgres (sandbox) required. Base court spawns the real gymact
uvicorn subprocess. Consequential DO remains behind `prepare_external` ->
DO -> `seal_external`; `Xaas.Actuation.run/4` authority paths untouched;
`:actuate_status` not exposed (the courts pass `Provider, :actuate_status`
through `actuate_local/4`, which routes through `Xaas.Actuation.run/4`
unchanged).

## Cleanup (incomplete — coordinator)

`rm -rf _build-laneW707` and `rm -rf test/w707_tmp` were denied by the
harness (same as W674). Left for the coordinator (verified on disk after
the run): `_build-laneW707/` (lane build-root lease) and `test/w707_tmp/`
(empty probe scaffold dir — its test file was replaced by a direct probe
then the dir left behind; delete both).

## Falsifiers

- A non-2xx remote whose failure leaves NO `:failed` receipt row → fix
  regressed.
- `actuate/4` without `:episode_id`/`:cut` raising (rather than returning
  `{:error, %Refusal{}}`) → fix regressed.
