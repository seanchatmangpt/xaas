defmodule Xaas.Sjira.RemainderCourtW984iqTest do
  @moduledoc """
  Unclaimed-family remainder court (lane W984iq).

  Census finding: the remaining sjira modules carry branch-level tests
  (atlassian_test, delivery_batch_depth_court, governance_route_test,
  governance_obligation_test, successor_test, engineer_workflow_test,
  yield/honesty courts), but the following genuinely unexercised
  state-bearing branches existed. Each test names its mutation rationale:
  the concrete mutation of lib/ the test kills.

  ard_court is exercised by ard_court_test.exs (drift repair landed in this
  lane: ARD-005/ARD-009 pinned refusal refreshed for ClosureResidual +
  MarketplaceCapabilityDelta; see test/xaas/sjira/ard_court_test.exs and
  docs/sjira/v26.10.6/plans/w984iq-probe.md).
  """

  use ExUnit.Case, async: true

  alias Xaas.Sjira.Atlassian
  alias Xaas.Sjira.DeliveryBatch
  alias Xaas.Sjira.GovernanceObligation
  alias Xaas.Sjira.GovernanceRoute

  # ------------------------------------------------------------ Atlassian

  describe "Atlassian.classify_response unexercised refusal classes" do
    defp env do
      %{
        semantic_id: "sj-1",
        idempotency_key: "sha256:abc"
      }
    end

    test "401/403 are provider_authority refusals, not generic status refusals" do
      # Mutation rationale: mapping 401/403 into the catch-all
      # {:provider_status, status} branch would pass the existing suite
      # (only 400/404/412/429/503 pinned); this kills it.
      for status <- [401, 403] do
        d = Atlassian.classify_response(status, %{"message" => "nope"}, env())
        assert d.disposition == :refused
        assert d.class == :provider_authority
        assert d.retry == false
        assert d.detail == %{"message" => "nope"}
      end
    end

    test "404 is provider_subject_missing, distinct from authority refusal" do
      # Mutation rationale: collapsing 404 into the authority or catch-all
      # branch passes today; kills the cross-class mutation.
      d = Atlassian.classify_response(404, %{"errors" => %{}}, env())
      assert d.class == :provider_subject_missing
      assert d.disposition == :refused
    end

    test "an unmapped status (410) falls to the {:provider_status, s} catch-all" do
      # Mutation rationale: deleting the catch-all clause raises instead of
      # refusing; also kills class-swap mutations among mapped statuses.
      d = Atlassian.classify_response(410, "gone", env())
      assert d.class == {:provider_status, 410}
      assert d.detail == "gone"
    end

    test "408/409/425 map to distinct retry classes and 502 to provider_unavailable" do
      # Mutation rationale: retry_class/1 heads beyond 429/503 are unpinned;
      # a regression folding 409 into :timeout passes today.
      assert Atlassian.classify_response(408, %{}, env()).class == :timeout
      assert Atlassian.classify_response(409, %{}, env()).class == :provider_conflict
      assert Atlassian.classify_response(425, %{}, env()).class == :too_early
      assert Atlassian.classify_response(502, %{}, env()).class == :provider_unavailable
      assert Atlassian.classify_response(504, %{}, env()).class == :provider_unavailable
    end

    test "retry_after honors retry_after_ms and ignores non-integer retryAfter" do
      # Mutation rationale: the retry_after_ms header branch and the
      # is_integer guard are unexercised; a mutation returning n (seconds,
      # not ms) for retry_after_ms would pass today.
      assert Atlassian.classify_response(429, %{"retry_after_ms" => 750}, env()).retry_after_ms ==
               750

      assert Atlassian.classify_response(429, %{"retryAfter" => "soon"}, env()).retry_after_ms ==
               nil
    end

    test "412 reconcile detail surfaces errorMessages when errors is absent" do
      # Mutation rationale: errors/1 clauses for errorMessages/other are
      # unexercised; a mutation dropping the errorMessages clause passes.
      d = Atlassian.classify_response(412, %{"errorMessages" => ["stale"]}, env())
      assert d.disposition == :reconcile
      assert d.detail == ["stale"]
    end

    test "accepted classification reads an atom-keyed provider key" do
      # Mutation rationale: key/1's atom-key head is unexercised; deleting it
      # still passes the string-keyed 201 test.
      d =
        Atlassian.classify_response(
          201,
          %{key: "XAAS-9"},
          env()
        )

      assert d.disposition == :accepted
      assert d.provider_key == "XAAS-9"
    end
  end

  describe "Atlassian.project unexercised projection branches" do
    defp item(over \\ %{}) do
      Map.merge(
        %{
          "identity" => "SJ-1",
          "project_key" => "XAAS",
          "issue_type" => "Task",
          "summary" => "do the thing"
        },
        over
      )
    end

    test "atom-keyed item projects identically (atom access path)" do
      # Mutation rationale: str/2 and require_fields/1 atom-key fallbacks are
      # unexercised; removing them passes the string-key tests.
      {:ok, env} =
        Atlassian.project(%{
          identity: "SJ-1",
          project_key: "XAAS",
          issue_type: "Task",
          summary: "do the thing"
        })

      assert env.method == :post
      assert env.body.fields.summary == "do the thing"
    end

    test "a non-map item is {:error, {:invalid_item, item}}" do
      # Mutation rationale: the project(other, _) head is unexercised.
      assert {:error, {:invalid_item, "junk"}} = Atlassian.project("junk")
    end

    test "an empty required field is a missing_fields refusal naming the field" do
      # Mutation rationale: present?/1's empty-string arm is unexercised;
      # treating "" as present passes today.
      assert {:error, {:missing_fields, fields}} = Atlassian.project(item(%{"summary" => ""}))
      assert "summary" in fields
    end

    test "field_map projects custom source fields onto provider fields" do
      # Mutation rationale: custom/3 is entirely unexercised; a mutation
      # dropping the reduce passes the default-field tests.
      {:ok, env} =
        Atlassian.project(item(%{"team" => "platform"}), field_map: %{"team" => "customfield_1"})

      assert env.body.fields["customfield_1"] == "platform"

      {:ok, env2} =
        Atlassian.project(item(), field_map: %{"absent_source" => "customfield_2"})

      refute Map.has_key?(env2.body.fields, "customfield_2")
    end

    test "labels are sanitized, deduplicated and sorted; base labels always present" do
      # Mutation rationale: sanitize/1's hostile-character replacement, trim
      # and the uniq/sort pipeline are unexercised; dropping sanitize would
      # still pass plain-label tests.
      {:ok, env} = Atlassian.project(item(%{"labels" => ["Semantic Jira", "UPPER Case!!"]}))

      assert env.body.fields.labels ==
               ["semantic-jira", "sj-sj-1", "semantic-jira", "upper-case"]
               |> Enum.uniq()
               |> Enum.sort()
    end

    test "an update path URI-encodes the provider key" do
      # Mutation rationale: URI.encode in the update head is unexercised; a
      # mutation concatenating raw keys passes the plain-key update test.
      {:ok, env} = Atlassian.project(item(%{"provider_key" => "XAAS 42/sp"}))

      assert env.method == :put
      assert env.path == "/rest/api/3/issue/XAAS%2042/sp"
    end

    test "an oversized summary is truncated to the limit; custom limit honored" do
      # Mutation rationale: truncate/2's over-limit arm is unexercised for
      # the summary default.
      long = String.duplicate("x", 300)
      {:ok, env} = Atlassian.project(item(%{"summary" => long}))
      assert String.length(env.body.fields.summary) == 255

      {:ok, env2} = Atlassian.project(item(%{"summary" => long}), summary_limit: 10)
      assert String.length(env2.body.fields.summary) == 10
    end
  end

  # -------------------------------------------------------- DeliveryBatch

  describe "DeliveryBatch unexercised intake refusals" do
    defp dep_item(id, deps \\ []) do
      %{
        "identity" => id,
        "project_key" => "XAAS",
        "issue_type" => "Task",
        "summary" => "item #{id}",
        "depends_on" => deps
      }
    end

    test "a nil identity refuses with {:missing_identity, item}" do
      # Mutation rationale: index/2's nil arm is unexercised; a mutation
      # defaulting nil to "" passes today.
      bad = dep_item(nil)

      assert {:error, {:missing_identity, ^bad}} = DeliveryBatch.plan([bad])
    end

    test "a duplicate identity refuses naming the id" do
      # Mutation rationale: the Map.has_key? arm of index/2 is unexercised;
      # letting duplicates through silently passes.
      assert {:error, {:duplicate_identity, "A"}} =
               DeliveryBatch.plan([batch_item("A"), batch_item("A")])
    end

    test "an unknown dependency refuses with the {id, dep} pairs" do
      # Mutation rationale: topo/1's missing-dep arm is unexercised.
      assert {:error, {:missing_dependencies, [{"B", "A"}]}} =
               DeliveryBatch.plan([dep_item("B", ["A"])])
    end

    test "a dependency cycle refuses naming the remaining ids" do
      # Mutation rationale: kahn/3's empty-ready arm is unexercised; a
      # mutation looping forever instead of refusing passes today.
      assert {:error, {:dependency_cycle, cycle}} =
               DeliveryBatch.plan([dep_item("A", ["B"]), dep_item("B", ["A"])])

      assert Enum.sort(cycle) == ["A", "B"]
    end

    test "an item whose projection fails halts the whole plan" do
      # Mutation rationale: project/2's {:halt, ...} arm is unexercised;
      # skipping the failing item and planning the rest would pass today.
      assert {:error, {:projection_failed, "BAD", {:missing_fields, _}}} =
               DeliveryBatch.plan([batch_item("OK"), batch_item("BAD") |> Map.put("summary", "")])
    end
  end

  describe "DeliveryBatch checkpoint failure recording" do
    defp planned(ids) do
      {:ok, plan} =
        DeliveryBatch.plan(Enum.map(ids, &batch_item/1))

      plan
    end

    defp batch_item(id) do
      %{
        "identity" => id,
        "project_key" => "XAAS",
        "issue_type" => "Task",
        "summary" => "item #{id}"
      }
    end

    test "record of a non-accepted outcome moves the id to failed with json_safe detail" do
      # Mutation rationale: record/3's failure head and json_safe/1's atom and
      # list arms are unexercised; stringifying nothing still passes the
      # accepted-record tests.
      plan = planned(["A", "B"])
      %{checkpoint: cp} = plan

      outcome = %{
        disposition: :refused,
        class: :provider_authority,
        detail: ["nope", :forbidden]
      }

      cp2 = DeliveryBatch.record(cp, "A", outcome)
      assert cp2.failed["A"]["class"] == "provider_authority"
      assert cp2.failed["A"]["detail"] == ["nope", "forbidden"]
      assert "A" not in cp2.pending

      # Roundtrip through the real json codec: failure survives.
      {:ok, cp3} =
        cp2 |> DeliveryBatch.checkpoint_json() |> DeliveryBatch.checkpoint_from_json()

      assert cp3.failed["A"]["class"] == "provider_authority"
      assert DeliveryBatch.complete?(cp3) == false
    end

    test "recording every pending id as accepted completes the checkpoint" do
      # Mutation rationale: complete?/1 is unexercised; an inverted predicate
      # passes existing partial-record tests.
      plan = planned(["A", "B"])
      cp = plan.checkpoint

      cp =
        Enum.reduce(plan.checkpoint.pending, cp, fn id, acc ->
          DeliveryBatch.record(acc, id, %{disposition: :accepted})
        end)

      assert DeliveryBatch.complete?(cp)
      assert cp.completed == ["A", "B"]

      {:ok, cp2} =
        cp |> DeliveryBatch.checkpoint_json() |> DeliveryBatch.checkpoint_from_json()

      assert DeliveryBatch.complete?(cp2)
    end

    test "checkpoint_from_json refuses a wrong version byte-for-byte typed" do
      # Mutation rationale: the `1 <- m["version"]` guard arm is unexercised
      # (existing court covers garbage/wrong-shape, not version).
      garbage =
        Jason.encode!(%{
          "version" => 2,
          "batch_digest" => "sha256:x",
          "completed" => [],
          "pending" => [],
          "failed" => %{}
        })

      assert {:error, :invalid_checkpoint} = DeliveryBatch.checkpoint_from_json(garbage)
    end
  end

  # ------------------------------------------------------- GovernanceRoute

  describe "GovernanceRoute unexercised refusal codes" do
    defp finding(id, disposition \\ "REWORK") do
      %{
        "id" => id,
        "required_action" => "REMEDIATE_#{id}",
        "action_owner" => "Platform Team",
        "evidence_required" => "evidence:#{id}",
        "disposition" => disposition
      }
    end

    defp gate_result(findings) do
      %{"gate" => "security", "phase" => "design", "findings" => findings}
    end

    defp compile_ok!(subject, findings \\ [finding("G-001")]) do
      {:ok, obligations, receipt} =
        GovernanceRoute.compile([gate_result(findings)], subject_ref: subject)

      {obligations, receipt}
    end

    test "compile with a non-list gate_results is GATE_RESULTS_MUST_BE_LIST" do
      # Mutation rationale: the compile/2 catch-all head is unexercised; a
      # mutation raising FunctionClauseError instead passes today.
      assert {:refused, r} = GovernanceRoute.compile("not-a-list", subject_ref: "s")
      assert r["reason"] == "GATE_RESULTS_MUST_BE_LIST"
    end

    test "compile with a missing subject_ref is SUBJECT_REF_REQUIRED" do
      # Mutation rationale: the subject_ref cond arm is unexercised; deleting
      # it makes the empty route the first refusal instead.
      for subject <- [nil, ""] do
        assert {:refused, r} =
                 GovernanceRoute.compile([gate_result([finding("G-1")])], subject_ref: subject)

        assert r["reason"] == "SUBJECT_REF_REQUIRED"
      end
    end

    test "compile carries a per-gate refusal as GATE_COMPILATION_REFUSED with gate index" do
      # Mutation rationale: compile_all's {:halt, refusal} arm is unexercised;
      # a mutation swallowing the halt (skipping bad gates) passes today.
      assert {:refused, r} =
               GovernanceRoute.compile(
                 [gate_result(["junk-finding"])],
                 subject_ref: "sjira:wo:1"
               )

      assert r["reason"] == "GATE_COMPILATION_REFUSED"
      assert r["detail"].gate_index == 0
      assert r["detail"].cause["reason"] == "FINDING_MUST_BE_MAP"
      assert r["detail"].cause["detail"].index == 0
    end

    test "replay with obligations of a foreign subject is SUBJECT_MISMATCH" do
      # Mutation rationale: same_subject/2's foreign arm is unexercised;
      # deleting it falls through to the digest mismatch instead of naming
      # the foreign obligations.
      {_obligations, receipt} = compile_ok!("sjira:wo:1")
      {foreign, _receipt2} = compile_ok!("sjira:wo:2")

      assert {:refused, r} = GovernanceRoute.replay(foreign, receipt)
      assert r["reason"] == "GOVERNANCE_ROUTE_SUBJECT_MISMATCH"
      assert r["detail"].foreign_obligations == [hd(foreign).obligation_id]
    end

    test "replay with a tampered obligation is OBLIGATION_REPLAY_REFUSED" do
      # Mutation rationale: verify_all's {:halt, ...} arm is unexercised; a
      # mutation skipping per-obligation replay passes today.
      {obligations, receipt} = compile_ok!("sjira:wo:1")
      [obligation] = obligations

      tampered = %{obligation | standing: :authorized}

      assert {:refused, r} = GovernanceRoute.replay([tampered], receipt)
      assert r["reason"] == "OBLIGATION_REPLAY_REFUSED"
      assert r["detail"].obligation_index == 0
    end
  end
end
