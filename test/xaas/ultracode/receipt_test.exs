defmodule Xaas.Ultracode.ReceiptTest do
  @moduledoc """
  Chicago-style qualification for `Xaas.Ultracode.Receipt`'s real lawful
  read path (the `:for_epoch` action + its narrow `bypass` -- see that
  resource's moduledoc "Real lawful read path" section). Real sandboxed
  Postgres rows via real Ash actions; `Receipt.for_epoch/1` itself is
  called with NO `authorize?: false` anywhere in this test's own
  assertions, so it goes through the real `Ash.Policy.Authorizer` with
  `actor: nil`, exactly as an HTTP caller behind `RequireInternalApiToken`
  would (that plug supplies no per-caller Ash actor -- see
  `XaasWeb.Plugs.ResolveOrgActor`'s own moduledoc).

  Proves two things together, since either alone is an incomplete fix:

    * the new path is real and correctly scoped: `Receipt.for_epoch/1`
      returns the real sealed row(s) for the given epoch only, never
      another epoch's;
    * the floor still holds: the resource's own bare, unscoped `:read`
      action never surfaces a real sealed row to an unauthorized caller --
      this fix is a narrow carve-out, not a reversal of the original
      deny-by-default decision recorded in the resource's own moduledoc.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.{Epoch, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp run_and_epoch(subject) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "Qualify the receipt read path.", provider: "zcode-receipt-test"},
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{run_id: run.id, cycle: 0, exact_subject: subject, state: :running},
        authorize?: false
      )
      |> Ash.create()

    epoch
  end

  # A qualifying terminal court: head_verified plus a passing fabric
  # verifier -- the ONLY evidence shape that may manufacture `:alive`
  # (`Validations.AliveRequiresCourt`).
  @court_evidence %{
    "head_verified" => true,
    "fabric_verifier" => %{"status" => "pass"}
  }

  defp seal_receipt(epoch, subject, evidence \\ @court_evidence) do
    Receipt
    |> Ash.Changeset.for_create(
      :seal,
      %{
        epoch_id: epoch.id,
        subject: subject,
        outcome: :alive,
        evidence: evidence,
        sealed_at: DateTime.utc_now()
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  describe "for_epoch/1 -- the real lawful read path" do
    test "returns the real sealed receipt for its own epoch, with NO authorize?: false" do
      epoch = run_and_epoch("Xaas.Ultracode.ReceiptTest own-epoch")
      receipt = seal_receipt(epoch, "own-epoch")

      assert {:ok, [read_back]} = Receipt.for_epoch(epoch.id)
      assert read_back.id == receipt.id
      assert read_back.outcome == :alive
      assert read_back.evidence == @court_evidence
    end

    test "is scoped: a different epoch's receipts are never returned" do
      epoch_a = run_and_epoch("epoch-a")
      receipt_a = seal_receipt(epoch_a, "epoch-a")

      epoch_b = run_and_epoch("epoch-b")
      _receipt_b = seal_receipt(epoch_b, "epoch-b")

      assert {:ok, [only]} = Receipt.for_epoch(epoch_a.id)
      assert only.id == receipt_a.id
      refute only.epoch_id == epoch_b.id
    end

    test "an epoch with no sealed receipts returns a real empty list, not an error" do
      epoch = run_and_epoch("no-receipts-yet")

      assert Receipt.for_epoch(epoch.id) == {:ok, []}
    end
  end

  describe "the deny-by-default floor still holds" do
    test "the bare, unscoped :read action never surfaces the real sealed row" do
      epoch = run_and_epoch("floor-still-holds")
      receipt = seal_receipt(epoch, "floor-still-holds")

      case Ash.read(Receipt) do
        {:ok, rows} ->
          refute Enum.any?(rows, &(&1.id == receipt.id))

        {:error, %Ash.Error.Forbidden{}} ->
          :ok

        {:error, other} ->
          flunk("expected Forbidden or a filtered empty read, got: #{inspect(other)}")
      end
    end
  end

  describe "the alive-requires-court sealing law" do
    test "a terminal-court seal (head_verified + fabric verifier pass) yields :alive" do
      epoch = run_and_epoch("court-alive")

      assert %Receipt{} = seal_receipt(epoch, "court-alive")
    end

    test "an :alive seal with NO court evidence is REFUSED, not sealed" do
      epoch = run_and_epoch("alive-no-court")

      assert {:error, error} =
               Receipt
               |> Ash.Changeset.for_create(
                 :seal,
                 %{
                   epoch_id: epoch.id,
                   subject: "alive-no-court",
                   outcome: :alive,
                   evidence: %{"note" => "trust me"},
                   sealed_at: DateTime.utc_now()
                 },
                 authorize?: false
               )
               |> Ash.create()

      refute match?(%Receipt{}, error)
      assert Exception.message(error) =~ "REFUSED_ALIVE_WITHOUT_COURT"
    end

    test "an :alive seal with head_verified but NO passing verifier verdict is REFUSED" do
      epoch = run_and_epoch("alive-head-only")

      assert {:error, error} =
               Receipt
               |> Ash.Changeset.for_create(
                 :seal,
                 %{
                   epoch_id: epoch.id,
                   subject: "alive-head-only",
                   outcome: :alive,
                   evidence: %{"head_verified" => true},
                   sealed_at: DateTime.utc_now()
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert Exception.message(error) =~ "REFUSED_ALIVE_WITHOUT_COURT"
    end

    test "an :alive seal with a passing verifier but head_verified false is REFUSED" do
      epoch = run_and_epoch("alive-unverified-head")

      assert {:error, error} =
               Receipt
               |> Ash.Changeset.for_create(
                 :seal,
                 %{
                   epoch_id: epoch.id,
                   subject: "alive-unverified-head",
                   outcome: :alive,
                   evidence: %{
                     "head_verified" => false,
                     "fabric_verifier" => %{"status" => "pass"}
                   },
                   sealed_at: DateTime.utc_now()
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert Exception.message(error) =~ "REFUSED_ALIVE_WITHOUT_COURT"
    end

    test "a tick heartbeat seals as the typed non-standing :heartbeat class, never :alive" do
      epoch = run_and_epoch("tick-heartbeat")

      {:ok, receipt} =
        Receipt
        |> Ash.Changeset.for_create(
          :seal,
          %{
            epoch_id: epoch.id,
            subject: "tick-heartbeat",
            outcome: :heartbeat,
            evidence: %{
              "expected_state" => "running",
              "observed_state" => "running",
              "action_taken" => "await_provider"
            },
            sealed_at: DateTime.utc_now()
          },
          authorize?: false
        )
        |> Ash.create()

      assert receipt.outcome == :heartbeat
      assert receipt.evidence["action_taken"] == "await_provider"

      # The typed class, readable back through the real lawful read path.
      assert {:ok, [read_back]} = Receipt.for_epoch(epoch.id)
      assert read_back.outcome == :heartbeat
    end

    test "an unverified :partial_alive still seals (the honest downgrade class)" do
      epoch = run_and_epoch("partial-no-court")

      {:ok, receipt} =
        Receipt
        |> Ash.Changeset.for_create(
          :seal,
          %{
            epoch_id: epoch.id,
            subject: "partial-no-court",
            outcome: :partial_alive,
            evidence: %{"head_verified" => false, "verifier_unavailable" => "no_worktree"},
            sealed_at: DateTime.utc_now()
          },
          authorize?: false
        )
        |> Ash.create()

      assert receipt.outcome == :partial_alive
    end
  end
end
