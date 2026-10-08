defmodule Xaas.Library.AuthorshipCourtW984kaTest do
  @moduledoc """
  Lane W984ka — unclaimed-family probe on `lib/xaas/library/`.

  Census result: no dedicated author/subject/topic/category resources exist;
  the unclaimed candidates were `RecommendationLog`, `Curation`, `Embeddings`,
  `Explainer`, `PersonaGrant`, `Ranker`, the `Changes.*` helpers, and the
  reactors. All except one are covered or indirectly covered:

    - `Curation`, `Embeddings`, `Explainer`, `PersonaGrant`, `Ranker`:
      each has a dedicated test file (COVERED).
    - `RecommendationLog` behavior is exercised via next_read tests, but
      always `authorize?: false`, so its DENY-BY-DEFAULT POLICY FLOOR
      (`policy action_type([:create, :update, :destroy]) authorize_if
      actor_present()`) and guest read branch were UNCOVERED state-bearing
      branches. This court exercises the real policy evaluation over real
      Postgres, no mocks.
    - `Changes.WriteActorResolutionAudit` is indirectly covered by the A2A
      persona tests asserting real `a2a.actor_resolution.*` audit rows.
    - `Changes.EnforceBorrowCap` is indirectly covered by
      checkout_hold_lifecycle_stress_test.exs (cap refusal on :fulfill).
    - inventory changes + reactors: covered by checkout/cascade/reactor
      courts.

  Mutation rationale (generate-and-kill): for each policy branch, the
  falsifier is that mutating the policy (e.g. dropping `authorize_if
  actor_present()` from the mutation policy, or requiring an actor for
  reads) flips the observed verdict — the test observes the real
  authorization decision, so a policy mutation cannot pass silently.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.RecommendationLog

  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_user!(attrs \\ %{}), do: Xaas.Generator.create_user!(attrs)

  defp log_attrs(user) do
    %{
      user_id: user.id,
      candidate_pool_size: 3,
      ranked_items: [%{"book_id" => "b1", "score" => 0.9}],
      accepted: false
    }
  end

  describe "RecommendationLog deny-by-default policy floor" do
    test "guest (no actor) CAN read — documented guest-browse branch" do
      user = create_user!()

      RecommendationLog
      |> Ash.Changeset.for_create(:create, log_attrs(user), authorize?: false)
      |> Ash.create!(authorize?: false)

      read =
        RecommendationLog
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read(actor: nil)

      assert match?({:ok, [%RecommendationLog{} | _]}, read),
             "guest read of recommendation logs must be allowed"
    end

    test "anonymous create WITHOUT an actor is refused with Forbidden" do
      user = create_user!()

      result =
        RecommendationLog
        |> Ash.Changeset.for_create(:create, log_attrs(user))
        |> Ash.create(actor: nil)

      assert {:error, %Ash.Error.Forbidden{}} = result

      # Real state: no row landed.
      assert [] ==
               RecommendationLog
               |> Ash.Query.filter(user_id == ^user.id)
               |> Ash.read!(authorize?: false),
             "a refused anonymous create must not leave a row behind"
    end

    test "actor-present create is allowed (real authorization, not authorize?: false)" do
      user = create_user!()

      assert {:ok, %RecommendationLog{} = log} =
               RecommendationLog
               |> Ash.Changeset.for_create(:create, log_attrs(user))
               |> Ash.create(actor: user)

      assert log.candidate_pool_size == 3
      assert log.accepted == false
    end

    test "update :accepted feedback toggle requires an actor; actor-present update succeeds" do
      user = create_user!()

      log =
        RecommendationLog
        |> Ash.Changeset.for_create(:create, log_attrs(user), authorize?: false)
        |> Ash.create!(authorize?: false)

      assert {:error, %Ash.Error.Forbidden{}} =
               log
               |> Ash.Changeset.for_update(:update, %{accepted: true})
               |> Ash.update(actor: nil)

      assert {:ok, %RecommendationLog{accepted: true} = updated} =
               log
               |> Ash.Changeset.for_update(:update, %{accepted: true})
               |> Ash.update(actor: user)

      # Real persisted state, re-read from the database.
      assert %RecommendationLog{accepted: true} =
               RecommendationLog |> Ash.get!(updated.id, authorize?: false)
    end

    test "destroy without actor is refused; destroy with actor succeeds" do
      user = create_user!()

      log =
        RecommendationLog
      |> Ash.Changeset.for_create(:create, log_attrs(user), authorize?: false)
      |> Ash.create!(authorize?: false)

      assert {:error, %Ash.Error.Forbidden{}} =
               log |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy(actor: nil)

      assert :ok = Ash.destroy(log, actor: user)

      assert [] ==
               RecommendationLog
               |> Ash.Query.filter(user_id == ^user.id)
               |> Ash.read!(authorize?: false),
             "destroy must remove the real row"
    end
  end
end
