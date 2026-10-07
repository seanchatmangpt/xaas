defmodule Xaas.Sa2aComputationBoundaryTest do
  @moduledoc """
  W763: dedicated court for the SA2A computation-boundary doctrine
  (docs/claude/diataxis/reference/sa2a-computation-boundary.md, W714-verified).

  Chicago style, no test doubles. Real constructors, real Registry gate, real
  fixtures, real Xaas.Actuation.run/4 over a sandboxed Provider row.

  Scope note: W741 covers the bridge layer; this court covers the computation
  surface (lib/xaas/semantics/computation.ex) plus the two boundary seams the
  doctrine doc pins (Route task carrier, Route.conserve/3).
  """

  use ExUnit.Case, async: false

  alias Xaas.Marketplace.Provider
  alias Xaas.Sa2a.Route
  alias Xaas.Semantics.{ComputationArtifact, ComputationClaim, PlanningAdvice, Registry}

  @fixture_dir Path.expand("../fixtures/sa2a_route", __DIR__)

  # contract field -> key inside the SA2A task's route-tuple data part
  @task_keys %{
    "subject" => "subject",
    "postcondition" => "postcondition",
    "capability" => "requiresCapability",
    "evidence_ceiling" => "evidenceCeiling",
    "authority_ceiling" => "authorityCeiling",
    "consequence_class" => "consequenceClass",
    "exclusions" => "exclusions"
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    order = read_json!("work_order.json")
    task = read_json!("sa2a_task.json")
    %{order: order, task: task, epoch: epoch_contract(order, task)}
  end

  # ---------------------------------------------------------------------------
  # (a) real construction + validation
  # ---------------------------------------------------------------------------

  describe "ComputationArtifact construction" do
    test "a well-formed artifact over a public capability IRI constructs" do
      assert {:ok, %ComputationArtifact{} = artifact} =
               ComputationArtifact.new(%{
                 artifact_identity: "w763-artifact",
                 capability_iri: "https://schema.org/ComputeAction",
                 runtime: "LLM",
                 input_schema_identity: "w763-in-v1",
                 output_schema_identity: "w763-out-v1",
                 input_projection_identity: "w763-proj-v1",
                 deterministic: false
               })

      assert artifact.runtime == "LLM"
      assert artifact.training_corpus_identity == nil
      assert artifact.calibration_identity == nil
      assert Registry.public_iri?(artifact.capability_iri)
    end

    test "a non-public capability IRI is refused with a typed error" do
      assert {:error, :non_public_capability_iri} =
               ComputationArtifact.new(%{
                 artifact_identity: "w763-artifact",
                 capability_iri: "urn:private:capability",
                 runtime: "LLM",
                 input_schema_identity: "in",
                 output_schema_identity: "out",
                 input_projection_identity: "proj",
                 deterministic: true
               })
    end

    test "an unsupported runtime is refused with the runtime named" do
      assert {:error, {:unsupported_runtime, "TENSORRT"}} =
               ComputationArtifact.new(%{
                 artifact_identity: "w763-artifact",
                 capability_iri: "https://schema.org/ComputeAction",
                 runtime: "TENSORRT",
                 input_schema_identity: "in",
                 output_schema_identity: "out",
                 input_projection_identity: "proj",
                 deterministic: true
               })
    end
  end

  describe "ComputationClaim construction" do
    test "a claim constructs with standing hard-wired to CANDIDATE" do
      assert {:ok, %ComputationClaim{} = claim} = claim(%{})
      assert claim.standing == "CANDIDATE"
      assert claim.authorizes_actuation == false
    end

    test "authorizes_actuation: true is refused with the dedicated typed error" do
      assert {:error, :computation_claim_cannot_authorize_actuation} =
               claim(%{authorizes_actuation: true})
    end

    test "a non-CANDIDATE standing is refused with the standing named" do
      assert {:error, {:computation_claim_standing_refused, "ADMITTED"}} =
               claim(%{standing: "ADMITTED"})
    end

    test "a non-public predicate IRI is refused" do
      assert {:error, :non_public_predicate_iri} =
               claim(%{predicate_iri: "urn:private:predicate"})
    end

    test "an evidence class outside the closed vocabulary is refused with the evidence-class atom (W782)" do
      # W763 finding G2 fix: the else-clause previously matched any failing
      # binary, so an out-of-vocabulary evidence_class surfaced mislabeled as
      # {:computation_claim_standing_refused, value}. The evidence-class check
      # now has its own refusal atom; the standing atom is reserved for
      # standing.
      assert {:error, {:computation_claim_invalid_evidence_class, "TELEPATHIC"}} =
               claim(%{evidence_class: "TELEPATHIC"})
    end

    test "a mislabeled standing refusal is not used for evidence-class failures (W782 regression)" do
      # Mutation rationale: reverting the validate_evidence_class extraction
      # routes "TELEPATHIC" back into the standing else-clause and this fails.
      # Also pins that the standing atom still fires for actual standing.
      assert {:error, {:computation_claim_standing_refused, "ADMITTED"}} =
               claim(%{standing: "ADMITTED", evidence_class: "OBSERVED"})

      assert {:error, {:computation_claim_invalid_evidence_class, _}} =
               claim(%{evidence_class: "TELEPATHIC", standing: "CANDIDATE"})
    end
  end

  # ---------------------------------------------------------------------------
  # exactly-one-kind-data-part rule (Route task hop)
  # ---------------------------------------------------------------------------

  describe "the exactly-one-kind-data-part rule" do
    test "the fixture task carries exactly one route-schema data part" do
      task = read_json!("sa2a_task.json")

      assert length(data_part_carriers(task)) == 1
      assert {:ok, tuple} = Route.tuple(task)
      assert tuple["capability"] =~ ~r/\A[a-z0-9][a-z0-9_.-]*:[a-z0-9][a-z0-9_.:-]*\z/
    end

    test "a second route-schema data part is refused as ambiguous" do
      task = read_json!("sa2a_task.json")

      dup = %{
        "kind" => "data",
        "data" => %{
          "schema" => Route.route_schema(),
          "tuple" => Map.put(task_tuple(task), "subject", "forged-second-carrier")
        }
      }

      forged = %{task | "input" => task["input"] ++ [dup]}

      assert length(data_part_carriers(forged)) == 2
      assert {:refused, {:ambiguous_tuple_carrier, 2}} = Route.tuple(:task, forged)
    end

    test "zero data parts refuse at the first missing contract field" do
      task = %{read_json!("sa2a_task.json") | "input" => []}

      # zero carriers => the empty tuple is projected, which refuses on the
      # first missing contract field rather than admitting a tuple nothing carried.
      assert {:refused, {:missing_field, "subject"}} = Route.tuple(:task, task)
    end
  end

  # ---------------------------------------------------------------------------
  # (b) candidate claims cannot authorize actuation
  # ---------------------------------------------------------------------------

  describe "candidate claims cannot authorize actuation" do
    @tag :w763_measured_gap
    @tag :w780_closed
    test "a CANDIDATE claim carried as the admission authority evidence is refused (W780 guard)" do
      provider = actuation_provider("W763 Boundary Provider")
      {:ok, claim} = claim(%{})

      # W763 measured the gap: this exact call USED to return
      # {:ok, %{status: :succeeded, replay?: false}} with the provider row
      # flipped to :active (real consequence across the boundary). W780 added
      # a structural guard in admit_authority/2: struct-shaped authority
      # evidence is refused, closed-set atom :claim_shaped_authority_refused.
      # Mutation rationale: drop the guard and admit_authority/2 accepts the
      # claim, so this assert is the first thing that fails -- the call
      # returns the old succeeded shape instead of the typed refusal, and the
      # provider row would flip to :active.
      assert {:error, {:reactor_failed,
                       %Reactor.Error.Invalid{errors: [
                         %Reactor.Error.Invalid.RunStepError{error: :claim_shaped_authority_refused}
                       ]}}} =
               Xaas.Actuation.run(
                 Provider,
                 :actuate_status,
                 %{status: :active},
                 subject_id: provider.id,
                 idempotency_key: "w763-claim-authority-#{System.unique_integer([:positive])}",
                 authorize?: false,
                 authority: claim
               )

      # no consequence crossed the boundary: the provider row is unchanged
      assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) != :active
    end

    test "a plain nonempty authority map also admits -- the channel checks shape, not content" do
      provider = actuation_provider("W763 Boundary Provider 2")

      assert {:ok, %{status: :succeeded, replay?: false}} =
               Xaas.Actuation.run(
                 Provider,
                 :actuate_status,
                 %{status: :active},
                 subject_id: provider.id,
                 idempotency_key: "w763-map-authority-#{System.unique_integer([:positive])}",
                 authorize?: false,
                 authority: %{kind: "w763_test_authority", source: "boundary_court"}
               )
    end
  end

  # ---------------------------------------------------------------------------
  # (c) order_formal/2 filter semantics
  # ---------------------------------------------------------------------------

  describe "PlanningAdvice.order_formal/2" do
    test "reorders formal candidates by score and never returns a foreign candidate" do
      {:ok, adv} =
        advice(%{
          candidates: [
            %{candidate_ref: "c3", score: 3.0},
            %{candidate_ref: "foreign", score: 100.0},
            %{candidate_ref: "c1", score: 1.0},
            %{candidate_ref: "c2", score: 2.0}
          ]
        })

      # "foreign" (score 100) outranks every formal ref but must never appear
      # in the result; formal refs are ordered highest score first
      assert {:ok, ["c3", "c2", "c1"]} =
               PlanningAdvice.order_formal(adv, ["c1", "c2", "c3"])
    end

    test "a duplicate formal ref is refused as non-unique" do
      {:ok, adv} = advice(%{candidates: [%{candidate_ref: "c1", score: 1.0}]})

      assert {:error, :formal_candidate_refs_must_be_unique} =
               PlanningAdvice.order_formal(adv, ["c1", "c1"])
    end

    test "unadvised formal refs are appended unchanged after the ranked ones" do
      {:ok, adv} = advice(%{candidates: [%{candidate_ref: "c2", score: 2.0}]})

      assert {:ok, ["c2", "c1", "c3"]} =
               PlanningAdvice.order_formal(adv, ["c1", "c2", "c3"])
    end
  end

  # ---------------------------------------------------------------------------
  # (d) conserve/3 names the first differing field
  # ---------------------------------------------------------------------------

  describe "Route.conserve/3 first-differing-field" do
    test "the intact fixture route conserves", %{order: order, task: task, epoch: epoch} do
      assert Route.conserve(order, task, epoch) == :ok
    end

    test "one field mutated at the task hop is refused naming that field, across the full field order" do
      order = read_json!("work_order.json")
      task = read_json!("sa2a_task.json")
      epoch = epoch_contract(order, task)

      Route.fields()
      |> Enum.map(fn field ->
        {field, Route.conserve(order, mutate_task_field(task, field), epoch)}
      end)
      |> Enum.each(fn {field, verdict} ->
        assert {:refused, %{broken_term: "admission_vacuous", field: ^field}} = verdict
      end)
    end

    test "when two fields differ, the earlier field in fields/0 order is named" do
      order = read_json!("work_order.json")
      task = read_json!("sa2a_task.json")
      epoch = epoch_contract(order, task)

      # "subject" mutated at the order hop, "consequence_class" at the task hop;
      # "subject" precedes "consequence_class" in fields/0, so "subject" is named.
      order = %{order | "subject" => order["subject"] <> "-mutated"}
      # consequence_class must stay in the closed vocabulary, so mutate it to a
      # different VALID class; otherwise the task hop refuses the field instead
      # of carrying a differing value into the digest comparison.
      task =
        update_in(
          task,
          [Access.key!("input"), Access.at(0), Access.key!("data"), Access.key!("tuple"), Access.key!("consequenceClass")],
          fn _ -> "verification" end
        )

      assert {:refused, %{broken_term: "admission_vacuous", field: "subject"}} =
               Route.conserve(order, task, epoch)
    end
  end

  # ---------------------------------------------------------------------------
  # (e) determinism x2
  # ---------------------------------------------------------------------------

  describe "determinism" do
    test "hashes and conserve verdicts are stable across repeat calls" do
      {:ok, artifact} =
        ComputationArtifact.new(%{
          artifact_identity: "w763-det",
          capability_iri: "https://schema.org/ComputeAction",
          runtime: "FOND",
          input_schema_identity: "in",
          output_schema_identity: "out",
          input_projection_identity: "proj",
          deterministic: true
        })

      {:ok, claim} =
        ComputationClaim.new(%{
          subject_identity: "w763-det-subject",
          predicate_iri: "https://schema.org/score",
          value: 0.42,
          artifact: artifact,
          evidence_class: "DERIVED"
        })

      {:ok, adv} = advice(%{candidates: [%{candidate_ref: "x", score: 1.0}]})

      assert ComputationArtifact.hash(artifact) == ComputationArtifact.hash(artifact)
      assert ComputationClaim.hash(claim) == ComputationClaim.hash(claim)
      assert PlanningAdvice.hash(adv) == PlanningAdvice.hash(adv)

      order = read_json!("work_order.json")
      task = read_json!("sa2a_task.json")
      epoch = epoch_contract(order, task)

      assert Route.conserve(order, task, epoch) == Route.conserve(order, task, epoch)

      {:ok, order_tuple} = Route.tuple(order)
      assert Route.digest(order_tuple) == Route.digest(order_tuple)
    end
  end

  # ---------------------------------------------------------------------------
  # helpers
  # ---------------------------------------------------------------------------

  defp claim(overrides) do
    {:ok, artifact} =
      ComputationArtifact.new(%{
        artifact_identity: "w763-claim-artifact",
        capability_iri: "https://schema.org/ComputeAction",
        runtime: "LLM",
        input_schema_identity: "in",
        output_schema_identity: "out",
        input_projection_identity: "proj",
        deterministic: false
      })

    ComputationClaim.new(
      Map.merge(
        %{
          subject_identity: "w763-subject",
          predicate_iri: "https://schema.org/score",
          value: 0.9,
          artifact: artifact,
          evidence_class: "OBSERVED"
        },
        overrides
      )
    )
  end

  defp advice(overrides) do
    {:ok, artifact} =
      ComputationArtifact.new(%{
        artifact_identity: "w763-advice-artifact",
        capability_iri: "https://schema.org/PlanAction",
        runtime: "HDDL",
        input_schema_identity: "in",
        output_schema_identity: "out",
        input_projection_identity: "proj",
        deterministic: false
      })

    PlanningAdvice.new(
      Map.merge(
        %{
          planning_subject_identity: "w763-planning-subject",
          formal_projection_identity: "w763-formal-projection",
          artifact: artifact,
          kind: "FRONTIER",
          candidates: []
        },
        overrides
      )
    )
  end

  defp actuation_provider(name) do
    Xaas.Generator.create_provider!(%{name: name, org_id: "org-w763"})
  end

  defp data_part_carriers(task) do
    task
    |> Map.fetch!("input")
    |> Enum.filter(&(&1["kind"] == "data" and &1["data"]["schema"] == Route.route_schema()))
  end

  defp task_tuple(task) do
    task |> data_part_carriers() |> hd() |> get_in(["data", "tuple"])
  end

  defp mutate_task_field(task, field) do
    key = Map.fetch!(@task_keys, field)

    update_in(
      task,
      [
        Access.key!("input"),
        Access.at(0),
        Access.key!("data"),
        Access.key!("tuple"),
        Access.key!(key)
      ],
      fn
        list when is_list(list) -> ["w763-mutated-exclusion" | list]
        value -> value <> " (w763 mutated)"
      end
    )
  end

  defp epoch_contract(order, task) do
    {:ok, {provider, _recipe}} = Route.resolve(order["requires_capability"])

    %{
      "work_order_iri" => task["taskId"],
      "checkpoint_iri" => "urn:semantic-jira:checkpoint:" <> order["next_checkpoint"],
      "graph_digest" => task["contextId"],
      "repository" => order["repository"],
      "execution_repo_alias" => "ggen_igniter",
      "base_sha" => order["base_sha"],
      "goal" => order["title"],
      "provider" => provider,
      "capability" => order["requires_capability"],
      "verifier_suite" => "ggen-igniter-format",
      "execution_policy" => "autonomic_wave_attempt",
      "dependencies" => [],
      "bridge" =>
        %{
          "subject" => order["subject"],
          "postcondition" => order["postcondition"],
          "requires_capability" => order["requires_capability"],
          "evidence_ceiling" => order["evidence_ceiling"],
          "authority_ceiling" => order["authority_ceiling"],
          "consequence_class" => order["consequence_class"],
          "exclusions" => order["exclusions"],
          "identity" => order["identity"],
          "replay_identity" => order["replay_identity"]
        }
    }
  end

  defp read_json!(name) do
    @fixture_dir
    |> Path.join(name)
    |> File.read!()
    |> Jason.decode!()
  end
end
