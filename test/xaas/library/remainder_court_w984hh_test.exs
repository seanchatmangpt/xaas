defmodule Xaas.Library.RemainderCourtW984hhTest do
  @moduledoc """
  Unclaimed-family remainder court (lane W984hh) for `lib/xaas/library/`
  modules no other court owns directly: the `Xaas.Library.School` resource
  itself (only ever touched indirectly as "High School" strings elsewhere)
  and the previously-unexercised fallback/override branches of
  `Xaas.Library.Config` (default-school precedence chain, pubsub topic
  fallback, weights override merge).

  Chicago style: real Ash resources against real Postgres via the sandbox,
  real application-env transitions with on_exit restore, zero mocks.

  Mutation rationale (kill-these-mutants): a mutant that (a) drops the
  `default?: true` filter in School's `:get_default` read, (b) inverts the
  `default_school_id/0` precedence order (app env > DB row > literal
  fallback), (c) breaks the `unique_slug` identity on School, (d) breaks
  the unknown-pubsub-key fallback `Map.get(topics, key, "library:\#{key}")`,
  or (e) breaks the `weights/1` opts-override merge — is killed by a
  dedicated assertion below.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Library.Config
  alias Xaas.Library.School
  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_school!(attrs \\ %{}) do
    School
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          slug: "school-#{Ash.UUID.generate()}",
          name: "Remainder Court School",
          domain: "remainder.school.edu"
        },
        attrs
      )
    )
    |> Ash.create!(authorize?: false)
  end

  describe "School resource" do
    test "get_default read returns only the school flagged default? == true" do
      nondefault = create_school!()
      default = create_school!(%{default?: true})

      got =
        School
        |> Ash.Query.for_read(:get_default)
        |> Ash.read_one!(authorize?: false)

      assert got.id == default.id
      assert got.id != nondefault.id
      assert got.default? == true
    end

    test "unique_slug identity refuses a duplicate slug with a real Ash error" do
      slug = "dup-#{Ash.UUID.generate()}"
      create_school!(%{slug: slug})

      assert {:error, %Ash.Error.Invalid{}} =
               School
               |> Ash.Changeset.for_create(:create, %{
                 slug: slug,
                 name: "Dup School",
                 domain: "dup.school.edu"
               })
               |> Ash.create()
    end

    test "create + read round-trips a real row" do
      school = create_school!(%{name: "Round Trip Academy", domain: "rt.school.edu"})

      assert %School{} = school
      assert school.name == "Round Trip Academy"

      fetched = Ash.get!(School, school.id, authorize?: false)
      assert fetched.domain == "rt.school.edu"
    end
  end

  describe "Config.default_school_id/0 precedence chain" do
    test "returns the real DB default-school slug when one is flagged default?" do
      school = create_school!(%{default?: true})

      assert Config.default_school_id() == school.slug
    end

    test "app-env override beats the DB default row" do
      create_school!(%{default?: true})

      Application.put_env(:xaas, :library_default_school_id, "env-override-district")
      on_exit(fn -> Application.delete_env(:xaas, :library_default_school_id) end)

      assert Config.default_school_id() == "env-override-district"
    end

    test "falls back to the willow-creek literal when no school is flagged default?" do
      # No School row flagged default? in this sandbox snapshot; also pin the
      # app env off in case another test leaked a config in.
      Application.delete_env(:xaas, :library_default_school_id)
      on_exit(fn -> Application.delete_env(:xaas, :library_default_school_id) end)

      assert Config.default_school_id() == "willow-creek"
    end
  end

  describe "Config.pubsub_topic/1" do
    test "returns the default topic for a known key" do
      assert Config.pubsub_topic(:recommendations) == "library:recommendations"
    end

    test "falls back to library:<key> for an unknown key" do
      assert Config.pubsub_topic(:definitely_not_a_topic) == "library:definitely_not_a_topic"
    end
  end

  describe "Config.weights/1 override merge" do
    test "opts weights override merges over the ontology-sourced base" do
      base = Config.weights()
      merged = Config.weights(weights: %{collab: 0.99})

      assert merged.collab == 0.99
      # untouched factors keep their real ontology/base values
      assert merged.semantic == base.semantic
      assert merged.grade_fit == base.grade_fit
    end

    test "top-level map argument merges over the base" do
      base = Config.weights()
      merged = Config.weights(%{diversity: 0.42})

      assert merged.diversity == 0.42
      assert merged.collab == base.collab
    end
  end
end
