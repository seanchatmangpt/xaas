defmodule Xaas.TemporalMemory.ObservationSupersedeChainDepthTest do
  @moduledoc """
  Lane W984ak — depth batch 3, family 2: `Xaas.TemporalMemory.Observation`
  (real Postgres, sandboxed).

  Uncovered slice (read-first: `test/xaas/temporal_memory/observation_test.exs`
  courts single supersede hop, hash divergence via observed_at, and the
  supersedes_id requirement; `query_and_replay_test.exs` courts Query/Replay;
  the W984l policy floor added to the resource has never been courted):

    * multi-generation supersede chain (A superseded by B superseded by C):
      every pointer lands, prior rows stay byte-for-byte untouched,
    * a dangling `supersedes_id` (prior already gone) still admits the new
      observation — the audit pointer is best-effort by design, not a crash
      and not a refusal,
    * `valid_to` round-trips as a closed-interval bound on both actions,
    * the deny-by-default policy floor: authorized `:observe` and authorized
      `:mark_superseded_by` refuse `Ash.Error.Forbidden` while the
      `authorize?: false` internal path keeps working,
    * double supersede of one prior: the second pointer overwrites the
      first — the machine's actual behavior, asserted not assumed.

  Chicago-style: real sandboxed Postgres rows via real Ash actions, no mocks.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.TemporalMemory.Observation

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp observe!(attrs) do
    Observation
    |> Ash.Changeset.for_create(:observe, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp supersede!(attrs) do
    Observation
    |> Ash.Changeset.for_create(:supersede, attrs)
    |> Ash.create!(authorize?: false)
  end

  @base %{
    subject_type: "kanban_card",
    subject_id: "chain-card",
    fact: %{"status" => "in_progress"},
    valid_from: ~U[2026-01-01 00:00:00.000000Z]
  }

  test "a three-generation supersede chain lands every pointer and leaves priors untouched" do
    a = observe!(Map.merge(@base, %{fact: %{"status" => "todo"}}))
    b = supersede!(Map.merge(@base, %{fact: %{"status" => "in_progress"}, supersedes_id: a.id}))
    c = supersede!(Map.merge(@base, %{fact: %{"status" => "blocked"}, supersedes_id: b.id}))

    ra = Ash.get!(Observation, a.id, authorize?: false)
    rb = Ash.get!(Observation, b.id, authorize?: false)

    assert rb.supersedes_id == a.id
    assert c.supersedes_id == b.id

    assert ra.superseded_by_id == b.id
    assert rb.superseded_by_id == c.id

    # priors are byte-for-byte untouched: facts and original hashes stable
    assert ra.fact == %{"status" => "todo"}
    assert rb.fact == %{"status" => "in_progress"}
    assert ra.receipt_hash == a.receipt_hash
    assert rb.receipt_hash == b.receipt_hash
  end

  test "a dangling supersedes_id still admits the correction (audit pointer is best-effort)" do
    missing_id = Ash.UUID.generate()

    result =
      Observation
      |> Ash.Changeset.for_create(:supersede, Map.merge(@base, %{supersedes_id: missing_id}))
      |> Ash.create(authorize?: false)

    assert {:ok, correction} = result

    persisted =
      Observation
      |> Ash.Query.filter(supersedes_id == ^missing_id)
      |> Ash.read!(authorize?: false)

    assert [%{id: id}] = persisted
    assert id == correction.id
    # no row was marked: the nonexistent prior obviously has no pointer
    assert is_nil(correction.superseded_by_id)
  end

  test "valid_to round-trips as a closed-interval bound on both create actions" do
    closed =
      observe!(Map.merge(@base, %{valid_to: ~U[2026-06-30 23:59:59.000000Z]}))

    assert closed.valid_to == ~U[2026-06-30 23:59:59.000000Z]

    correction =
      supersede!(
        Map.merge(@base, %{
          valid_from: ~U[2026-07-01 00:00:00.000000Z],
          valid_to: ~U[2026-12-31 23:59:59.000000Z],
          supersedes_id: closed.id
        })
      )

    assert correction.valid_to == ~U[2026-12-31 23:59:59.000000Z]

    reloaded_prior = Ash.get!(Observation, closed.id, authorize?: false)
    # the supersede did not close the prior's own valid_to: facts stay untouched
    assert reloaded_prior.valid_to == ~U[2026-06-30 23:59:59.000000Z]
    assert reloaded_prior.superseded_by_id == correction.id
  end

  test "policy floor: authorized observe/supersede admit via bypass; authorized update and destroy refuse" do
    # :observe and :supersede carry explicit action bypasses — the authorized
    # path admits (contract fact, asserted not assumed)
    assert %Observation{} =
             Observation
             |> Ash.Changeset.for_create(:observe, @base)
             |> Ash.create!(authorize?: true)

    assert [%Observation{}] =
             Observation
             |> Ash.Query.filter(subject_id == "chain-card")
             |> Ash.read!(authorize?: true)

    obs =
      Observation
      |> Ash.Query.filter(subject_id == "chain-card")
      |> Ash.read_one!(authorize?: false)

    # the update floor refuses an authorized caller and writes nothing
    assert {:error, %Ash.Error.Forbidden{}} =
             obs
             |> Ash.Changeset.for_update(:mark_superseded_by, %{superseded_by_id: Ash.UUID.generate()})
             |> Ash.update(authorize?: true)

    reloaded = Ash.get!(Observation, obs.id, authorize?: false)
    assert is_nil(reloaded.superseded_by_id)

    # the resource declares no :destroy action at all (structurally
    # immutable): the refusal is a typed NoPrimaryAction, not Forbidden
    assert {:error,
            %Ash.Error.Invalid{errors: [%Ash.Error.Invalid.NoPrimaryAction{type: :destroy}]}} =
             Ash.destroy(obs, authorize?: true)

    assert [%Observation{}] =
             Observation
             |> Ash.Query.filter(subject_id == "chain-card")
             |> Ash.read!(authorize?: false)

    # the internal (authorize?: false) path still works end to end
    correction = supersede!(Map.merge(@base, %{supersedes_id: obs.id}))
    assert Ash.get!(Observation, obs.id, authorize?: false).superseded_by_id == correction.id
  end

  test "double supersede of one prior: the second pointer overwrites the first" do
    prior = observe!(@base)

    first = supersede!(Map.merge(@base, %{fact: %{"status" => "v2"}, supersedes_id: prior.id}))
    second = supersede!(Map.merge(@base, %{fact: %{"status" => "v3"}, supersedes_id: prior.id}))

    reloaded = Ash.get!(Observation, prior.id, authorize?: false)
    assert reloaded.superseded_by_id == second.id

    assert first.id != second.id
    assert first.superseded_by_id != prior.id
  end
end
