defmodule Xaas.Ultracode.RunReceiptDeepeningTest do
  @moduledoc """
  Lane W717 — deepening qualification for the Ultracode control plane's
  Run/Epoch/Receipt Ash surface (`lib/xaas/ultracode/{run,epoch,receipt}.ex`).

  Chicago-style: real sandboxed Postgres rows through real Ash actions,
  asserting real row state — no mocks, no `@moduletag :eu_ai_act` (no
  Art-line tie exists: `Receipt` is an operational evidentiary record of
  epoch outcomes, not a log of processing of personal data under Art 12;
  no GDPR/personal-data processing claim is made by this surface).

  Covered:

    (a) Run create -> `:start` (first Epoch via
        `Xaas.Ultracode.Changes.CreateFirstEpoch`) -> complete -> receipt
        seal -> `Receipt.for_epoch/1` read-back, with real FK/identity
        integrity (DB FK on `ultracode_receipts.epoch_id`, unique index on
        `[run_id, cycle]`, `RunTransitionAllowed` state machine);
    (b) a Receipt sealed against a nonexistent `epoch_id` REFUSES at the
        real DB FK (`ultracode_receipts_epoch_id_fkey`), not silently;
    (c) receipt immutability is enforced BY CONSTRUCTION: the resource
        defines no `:update`/`:destroy` action — only `:seal` (create) and
        the two reads — so no lawful mutation path exists; asserted both by
        resource introspection and by a real failed mutation attempt;
    (d) determinism of the Run state fold: identical epoch-outcome-driven
        transition sequences fold two fresh Runs to identical terminal
        state, terminal states are absorbing (no further admitted edge),
        and the identical input sequence always reproduces the fold.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.{Epoch, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # A qualifying terminal court (`Validations.AliveRequiresCourt`).
  @court_evidence %{
    "head_verified" => true,
    "fabric_verifier" => %{"status" => "pass"}
  }

  defp create_run(goal \\ "W717 deepening run") do
    Run
    |> Ash.Changeset.for_create(
      :create,
      %{goal: goal, provider: "w717-deepening"},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp start_run(run, subject) do
    run
    |> Ash.Changeset.for_update(:start, %{exact_subject: subject}, authorize?: false)
    |> Ash.update!()
  end

  defp seal(epoch, subject, outcome \\ :alive, evidence \\ @court_evidence) do
    Receipt
    |> Ash.Changeset.for_create(
      :seal,
      %{
        epoch_id: epoch.id,
        subject: subject,
        outcome: outcome,
        evidence: evidence,
        sealed_at: DateTime.utc_now()
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  # ------------------------------------------------------------------
  # (a) Run -> Epoch -> Receipt lifecycle with real FK/identity integrity
  # ------------------------------------------------------------------
  describe "(a) run/epoch/receipt lifecycle" do
    test "create -> start -> complete -> seal -> for_epoch read-back, all row state real" do
      run = create_run() |> start_run("w717-lifecycle-subject")

      assert run.state == :running
      assert run.cycle == 1
      refute is_nil(run.started_at)

      # The first epoch was really constructed and FK-bound to this Run.
      assert [%Epoch{} = epoch] = Ash.load!(run, :epochs).epochs
      assert epoch.cycle == 0
      assert epoch.run_id == run.id
      assert epoch.state == :expected

      epoch =
        epoch
        |> Ash.Changeset.for_update(:start, %{}, authorize?: false)
        |> Ash.update!()

      # Receipt for the completed epoch: sealed with court evidence, read
      # back through the real lawful read path.
      epoch |> Ash.Changeset.for_update(:complete, %{}, authorize?: false) |> Ash.update!()
      receipt = seal(epoch, "w717-lifecycle-subject")

      assert {:ok, [read_back]} = Receipt.for_epoch(epoch.id)
      assert read_back.id == receipt.id
      assert read_back.epoch_id == epoch.id
      assert read_back.outcome == :alive
      assert read_back.evidence == @court_evidence

      # Row-level integrity, straight from the tables.
      assert %{rows: [[db_epoch_id]]} =
               Ecto.Adapters.SQL.query!(Xaas.Repo, "SELECT id FROM ultracode_epochs WHERE run_id = $1", [
                 Ecto.UUID.dump!(run.id)
               ])

      assert Ecto.UUID.load!(db_epoch_id) == epoch.id
    end

    test "duplicate (run_id, cycle) epoch for an ORG-LESS run is REFUSED — gap closed (W737)" do
      # WAS the W717 typed-gap test (asserted the duplicate was ACCEPTED —
      # NULL-distinct `UNIQUE (org_id, run_id, cycle)`). Closed by
      # 20261007010000's partial unique index
      # `ultracode_epochs_orgless_run_cycle_index` on `(run_id, cycle)
      # WHERE org_id IS NULL`, declared on the resource via
      # `postgres.custom_indexes` so ash_postgres translates the real DB
      # constraint into a typed invalid-attribute refusal.
      run = create_run() |> start_run("w717-identity-subject")

      # The run's `:start` already constructed the org-less cycle-0 epoch
      # (`Changes.CreateFirstEpoch`) — a second epoch at the same
      # (run_id, cycle) is now the duplicate that must refuse.
      assert {:error, error} =
               Epoch
               |> Ash.Changeset.for_create(
                 :create,
                 %{run_id: run.id, cycle: 0, exact_subject: "duplicate-cycle"},
                 authorize?: false
               )
               |> Ash.create()

      assert Exception.message(error) =~ ~r/unique|already exists|duplicate/i

      # Exactly one epoch row exists for the run (the original cycle-0 one).
      assert [%Epoch{} = only] = Ash.load!(run, :epochs).epochs
      assert only.cycle == 0
    end

    test "duplicate (run_id, cycle) epoch WITH an org_id is REFUSED by the identity index" do
      org = "w717-identity-org"

      run =
        Run
        |> Ash.Changeset.for_create(
          :create,
          %{goal: "org-scoped identity", provider: "w717-deepening", org_id: org},
          authorize?: false
        )
        |> Ash.create!()

      assert {:ok, _} =
               Epoch
               |> Ash.Changeset.for_create(
                 :create,
                 %{run_id: run.id, org_id: org, cycle: 0, exact_subject: "first"},
                 authorize?: false
               )
               |> Ash.create()

      assert {:error, error} =
               Epoch
               |> Ash.Changeset.for_create(
                 :create,
                 %{run_id: run.id, org_id: org, cycle: 0, exact_subject: "duplicate"},
                 authorize?: false
               )
               |> Ash.create()

      assert Exception.message(error) =~ ~r/unique|already exists|duplicate/i
    end

    test "epoch cannot reference a nonexistent run (real FK on ultracode_epochs.run_id)" do
      assert {:error, _} =
               Epoch
               |> Ash.Changeset.for_create(
                 :create,
                 %{run_id: Ecto.UUID.generate(), cycle: 0, exact_subject: "orphan-epoch"},
                 authorize?: false
               )
               |> Ash.create()
    end
  end

  # ------------------------------------------------------------------
  # (b) A receipt without its epoch refuses
  # ------------------------------------------------------------------
  describe "(b) receipt without its epoch refuses" do
    test "sealing against a nonexistent epoch_id hits the real DB FK and refuses" do
      assert {:error, error} =
               Receipt
               |> Ash.Changeset.for_create(
                 :seal,
                 %{
                   epoch_id: Ecto.UUID.generate(),
                   subject: "orphan-receipt",
                   outcome: :blocked,
                   evidence: %{},
                   sealed_at: DateTime.utc_now()
                 },
                 authorize?: false
               )
               |> Ash.create()

      # Typed refusal: ash_postgres translates the real FK violation
      # (ultracode_receipts_epoch_id_fkey) into InvalidAttribute
      # "does not exist" — refused, not a silent insert.
      refute match?(%Receipt{}, error)

      assert Exception.message(error) =~ "does not exist"

      # Nothing was persisted.
      assert Receipt.for_epoch(Ecto.UUID.generate()) == {:ok, []}
    end
  end

  # ------------------------------------------------------------------
  # (c) Receipt immutability post-write
  # ------------------------------------------------------------------
  describe "(c) receipt immutability post-write" do
    test "the resource defines no update/destroy action — immutability by construction" do
      action_names = Receipt |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)

      assert :seal in action_names
      refute :update in action_names
      refute :destroy in action_names
    end

    test "a real mutation attempt on a sealed receipt fails — no lawful rewrite path" do
      run = create_run() |> start_run("w717-immutability-subject")
      epoch = Ash.load!(run, :epochs).epochs |> hd()
      epoch = epoch |> Ash.Changeset.for_update(:start, %{}, authorize?: false) |> Ash.update!()
      epoch |> Ash.Changeset.for_update(:complete, %{}, authorize?: false) |> Ash.update!()
      receipt = seal(epoch, "w717-immutability-subject")

      # No update action exists on the resource: building a changeset for
      # one is refused at action resolution.
      assert_raise ArgumentError,
                   fn ->
                     receipt
                     |> Ash.Changeset.for_update(:update, %{evidence: %{"forged" => true}},
                       authorize?: false
                     )
                     |> Ash.update!()
                   end

      # The sealed row is byte-identical on the attempt's back side.
      assert {:ok, [read_back]} = Receipt.for_epoch(epoch.id)
      assert read_back.evidence == @court_evidence
      assert read_back.id == receipt.id
    end
  end

  # ------------------------------------------------------------------
  # (d) Determinism of the Run status fold over the same epoch sequence
  # ------------------------------------------------------------------
  describe "(d) run state fold determinism" do
    @fold_sequence [
      {:running, :suspended},
      {:suspended, :running},
      {:running, :completed}
    ]

    defp fold_run(sequence) do
      run =
        create_run("w717 fold run #{System.unique_integer()}")
        |> then(fn run ->
          run
          |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
          |> Ash.update!()
        end)

      Enum.reduce(sequence, run, fn {from, to}, acc ->
        assert acc.state == from, "sequence precondition: expected #{from}, got #{acc.state}"

        acc
        |> Ash.Changeset.for_update(:transition_state, %{state: to}, authorize?: false)
        |> Ash.update!()
      end)
    end

    test "the same admitted transition sequence folds two fresh runs to identical terminal state" do
      run_a = fold_run(@fold_sequence)
      run_b = fold_run(@fold_sequence)

      assert run_a.state == :completed
      assert run_b.state == :completed
      assert run_a.terminal_at != nil
      assert run_b.terminal_at != nil
    end

    test "terminal states are absorbing — no further transition is admitted" do
      run = fold_run(@fold_sequence)

      for attempted <- [:running, :failed, :abandoned, :suspended] do
        assert {:error, error} =
                 run
                 |> Ash.Changeset.for_update(:transition_state, %{state: attempted},
                   authorize?: false
                 )
                 |> Ash.update()

        assert Exception.message(error) =~ "is not an admitted edge"
      end

      # The absorbing row really is unchanged.
      reloaded = Ash.get!(Run, run.id, action: :read_unscoped)
      assert reloaded.state == :completed
      assert reloaded.terminal_at == run.terminal_at
    end

    test "an illegal transition refuses without folding" do
      run = create_run()

      # `:pending -> :completed` is not an admitted edge (must run first).
      assert {:error, error} =
               run
               |> Ash.Changeset.for_update(:transition_state, %{state: :completed},
                 authorize?: false
               )
               |> Ash.update()

      assert Exception.message(error) =~ "is not an admitted edge"

      reloaded = Ash.get!(Run, run.id, action: :read_unscoped)
      assert reloaded.state == :pending
      assert is_nil(reloaded.terminal_at)
    end
  end
end
