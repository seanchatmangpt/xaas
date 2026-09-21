defmodule Xaas.Ultracode.TestDbLeakGuardTest do
  @moduledoc """
  Permanent tripwire for the xaas_test leak class (帳 law: the ledger must
  not be poisoned by out-of-sandbox commits).

  Forensic history this test guards: wave-3 found 236 `ultracode_runs` /
  233 `ultracode_epochs` / 41 `ultracode_receipts` COMMITTED in `xaas_test`,
  poisoning every whole-table scan the suite performs (the reds then looked
  order/pollution-dependent); pg statistics show the true historical volume
  was thousands of inserts. The Ecto SQL sandbox itself cannot commit: every
  `Sandbox.checkout`/`start_owner!` proxy wraps the connection in a
  transaction rolled back on check-in, and `test/test_helper.exs` pins the
  ownership pool to `:manual` for the whole suite. A real COMMIT into
  `xaas_test` therefore means some writer bypassed sandbox ownership -- e.g.
  a `MIX_ENV=test` mix task or campaign VM (outside `mix test`,
  `test_helper.exs` never runs, so the pool sits in the default `:auto`
  mode where implicit checkouts are NOT sandbox-wrapped), a boot-time
  process, or the external dispatcher's psql.

  The law asserted here on the real database: the representative semantic
  write surface (Run+Epoch materialization plus a sealed Receipt) must be
  really written and visible inside the owning sandbox transaction, and
  must be GONE from the committed state of `xaas_test` the moment the owner
  stops -- i.e. the committed row counts of all three ultracode tables
  never move. If any code path ever commits outside the sandbox again,
  this test fails and names the leak, instead of the suite failing later
  with unexplainable whole-table-scan ghosts.
  """

  use ExUnit.Case, async: false

  import Xaas.Ultracode.SemanticCase

  alias Xaas.Ultracode.{Receipt, SemanticWork}

  setup do
    %{sha: sha} = put_semantic_fixture_env()
    %{sha: sha}
  end

  test "semantic ultracode writes roll back: committed xaas_test row counts never move", %{
    sha: sha
  } do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)

    before_counts = committed_row_counts()

    assert {:ok, %{run: run, epoch: epoch}} =
             SemanticWork.materialize(
               semantic_descriptor(sha, "leak-guard", "autonomic_wave_attempt")
             )

    # The writes are real, not vacuously passing: visible inside the owning
    # transaction (one Run, its first Epoch, and a sealed Receipt on top).
    assert %{rows: [[run_count, epoch_count, receipt_count]]} =
             Xaas.Repo.query!(
               """
               SELECT (SELECT count(*) FROM ultracode_runs WHERE id = $1::uuid),
                      (SELECT count(*) FROM ultracode_epochs WHERE run_id = $1::uuid),
                      (SELECT count(*) FROM ultracode_receipts WHERE epoch_id = $2::uuid)
               """,
               [Ecto.UUID.dump!(run.id), Ecto.UUID.dump!(epoch.id)]
             )

    assert run_count == 1
    assert epoch_count == 1

    assert {:ok, _receipt} =
             Receipt
             |> Ash.Changeset.for_create(
               :seal,
               %{
                 epoch_id: epoch.id,
                 subject: epoch.exact_subject,
                 outcome: :partial_alive,
                 evidence: %{"head_verified" => false}
               },
               authorize?: false
             )
             |> Ash.create()

    assert receipt_count == 0

    assert committed_row_counts() ==
             bump(before_counts, runs: 1, epochs: 1, receipts: 1)

    # Owner stop = rollback. From an independent sandbox transaction the
    # committed state must be exactly what it was before this test wrote
    # (catches a leak committed DURING this window)...
    Ecto.Adapters.SQL.Sandbox.stop_owner(owner)

    reader = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo)
    after_counts = committed_row_counts()
    Ecto.Adapters.SQL.Sandbox.stop_owner(reader)

    assert after_counts == before_counts,
           """
           xaas_test committed ultracode rows changed across a fully
           sandboxed write surface (before: #{inspect(before_counts)},
           after: #{inspect(after_counts)}). Some code path committed
           ultracode rows WITHOUT sandbox ownership -- the xaas_test leak
           class. Find the writer outside `mix test`'s sandboxed processes
           (a MIX_ENV=test mix task/campaign VM, a boot-time process, or
           external psql); do not delete rows and move on.
           """

    # ...and the committed state itself must be EMPTY (catches the
    # wave-3-class leak that is already committed before this suite runs
    # and poisons every whole-table scan afterwards).
    assert after_counts == {0, 0, 0},
           """
           xaas_test contains #{inspect(after_counts)} committed
           ultracode runs/epochs/receipts. The sandboxed suite cannot have
           put them there (every checkout rolls back), so a writer outside
           sandbox ownership leaked them -- the xaas_test leak class
           (wave-3: 236/233/41; pg history: thousands). Verify and clean
           the test DB rows only:
             psql -d xaas_test -c "SELECT count(*) FROM ultracode_runs;"
           and hunt the writer (MIX_ENV=test mix task / campaign VM,
           boot-time process, external psql). Never write xaas_dev.
           """
  end

  defp committed_row_counts do
    %{rows: [[runs, epochs, receipts]]} =
      Xaas.Repo.query!("""
      SELECT (SELECT count(*) FROM ultracode_runs),
             (SELECT count(*) FROM ultracode_epochs),
             (SELECT count(*) FROM ultracode_receipts)
      """)

    {runs, epochs, receipts}
  end

  defp bump({runs, epochs, receipts}, runs: dr, epochs: de, receipts: drc) do
    {runs + dr, epochs + de, receipts + drc}
  end
end
