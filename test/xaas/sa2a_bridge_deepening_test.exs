defmodule Xaas.Sa2a.BridgeDeepeningTest do
  @moduledoc """
  W741 lane: deepening the SA2A bridge/Executor surface's error and typed-refusal
  docket (docs: `docs/claude/diataxis/reference/sa2a-computation-boundary.md`).

  Chicago-style throughout: real `Port.open/2` OS subprocesses, real GenServer,
  real JSON-lines framing; no mocks of owned code.

  The port protocol under test (`Xaas.Sa2a.Bridge`):
    * a JSON line decoding to `%{"ok" => true}`  -> `{:ok, resp}`
    * a JSON line decoding to `%{"ok" => false}` -> `{:error, resp}`
    * a malformed line                           -> `{:error, {:invalid_json, reason, line}}`
    * process death mid-stream                   -> `{:error, {:port_exited, status}}`
      and the GenServer stops ({:stop, ...} init/handle_info contract)
    * authority admission is fail-closed BEFORE `Port.command/2` is touched
  """

  use ExUnit.Case, async: false

  @moduletag :subprocess

  alias Xaas.Sa2a.Bridge

  @fixture_dir Path.expand("../fixtures/sa2a_route", __DIR__)
  @registry_key :ultracode_construction_recipes

  setup do
    previous = Application.fetch_env(:xaas, @registry_key)

    Application.put_env(:xaas, @registry_key, %{
      "recipe:mix-format" => %{id: "mix-format", argv: ["mix", "format"]}
    })

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:xaas, @registry_key, value)
        :error -> Application.delete_env(:xaas, @registry_key)
      end
    end)

    order = read_json!("work_order.json")
    task = read_json!("sa2a_task.json")
    %{order: order, task: task}
  end

  # -- fixtures -------------------------------------------------------------

  defp read_json!(name), do: @fixture_dir |> Path.join(name) |> File.read!() |> Jason.decode!()

  defp jsonl_script do
    script = """
    #!/bin/sh
    n=0
    while IFS= read -r line; do
      n=$((n+1))
      if [ "$n" -eq 1 ]; then
        echo '{"ok":true,"ack":"valid"}'
      elif [ "$n" -eq 2 ]; then
        echo '{"ok":false,"code":"refused_by_peer"}'
      elif [ "$n" -eq 3 ]; then
        echo 'not-json-at-all'
      else
        exit 5
      fi
    done
    """

    path = Path.join(System.tmp_dir!(), "w741-jsonl-#{System.unique_integer([:positive])}.sh")
    File.write!(path, script)
    File.chmod!(path, 0o755)

    on_exit(fn ->
      _ = File.rm(path)
      :ok
    end)

    path
  end

  defp start_script_bridge! do
    start_supervised!({Bridge, port_command: jsonl_script(), port_args: []})
  end

  # `validate/1` op does not require authority per the generated MCP descriptor.
  defp validate do
    Bridge.validate(card_path: "/tmp/w741-card.json")
  end

  defp wait_until(fun, tries \\ 100) do
    if fun.() do
      true
    else
      if tries == 1, do: flunk("condition not reached"), else: Process.sleep(10)
      wait_until(fun, tries - 1)
    end
  end

  # -- the real port JSON-lines protocol ------------------------------------

  test "the real port JSON-lines sequence: valid, ok:false, malformed, mid-stream death" do
    refute Process.whereis(Bridge)
    pid = start_script_bridge!()

    # 1. valid JSON line decoding to ok:true -> {:ok, resp}, exact payload.
    assert {:ok, %{"ok" => true, "ack" => "valid"}} = validate()

    # 2. a JSON line decoding to ok:false -> the typed error envelope.
    assert {:error, %{"ok" => false, "code" => "refused_by_peer"}} = validate()

    # 3. a malformed line -> {:error, {:invalid_json, reason, raw_line}}; the
    #    {:line, N} framing hands the payload without the newline delimiter.
    assert {:error, {:invalid_json, %Jason.DecodeError{}, "not-json-at-all"}} = validate()

    # 4. process death mid-stream -> {:error, {:port_exited, status}} ...
    assert {:error, {:port_exited, 5}} = validate()

    # ... and the GenServer that owned the port stopped (handle_info
    # exit_status -> {:stop, ...}). The stop is async relative to the reply;
    # whatever the test supervisor's restart policy does afterwards is
    # supervisor policy, not bridge behavior.
    assert wait_until(fn -> not Process.alive?(pid) end)

    # a call after death never hangs on the dead port: with this supervisor's
    # restart policy the fresh incarnation (a brand-new port running a
    # brand-new script instance) round-trips cleanly.
    assert {:ok, %{"ok" => true}} = validate()
  end

  test "authority refusal happens before any port process exists" do
    refute Process.whereis(Bridge)

    assert {:error, :sa2a_authority_evidence_required} = Bridge.execute("SELECT 1", authority: %{})

    assert {:error, :sa2a_authority_evidence_required} =
             Bridge.execute("SELECT 1", authority: nil)

    # The GenServer was never started, so nothing reached a port: the refusal
    # is computed in the caller process by `call/2` -> `admit_authority/2`.
    refute Process.whereis(Bridge)

    # With real authority evidence the same call must now fail on the missing
    # GenServer (:noproc), proving the refusal above was admission-side, not
    # transport-side.
    assert catch_exit(Bridge.execute("SELECT 1", authority: %{granted_by: "w741"}))
           |> elem(0) == :noproc
  end

  test "init fails typed when the port executable is absent" do
    missing = Path.join(System.tmp_dir!(), "w741-missing-#{System.unique_integer([:positive])}")

    assert {:error, {{:executable_not_found, ^missing}, _child_spec}} =
             start_supervised({Bridge, port_command: missing, port_args: []})
  end

  # -- Executor -------------------------------------------------------------

  test "Executor routes through ensure_bridge and is typed BLOCKED when it is down" do
    refute Process.whereis(Bridge)

    request = %{
      "work_order_id" => "W741-1",
      "work_order_digest" => "sha256:" <> String.duplicate("ab", 32),
      "query" => "workorder:W741-1 probe"
    }

    assert {:error, {:blocked, :bridge_not_running}} =
             Xaas.Sa2a.Executor.execute(request, start_bridge?: false)
  end

  @tag :autofde_env_probe
  test "ensure_bridge(true) without autofde on PATH is typed BLOCKED with the exact remedy" do
    if Bridge.available?("autofde") do
      IO.puts("skipping: autofde IS on PATH in this environment")
    else
      assert {:error,
              {:blocked,
               {:autofde_not_on_path, "export PATH=$HOME/autofde-lab/.venv/bin:$PATH"}}} =
               Xaas.Sa2a.Executor.ensure_bridge(true)
    end
  end

  test "Executor is the sole sa2a caller of Xaas.Actuation.run and builds the authority context" do
    sa2a_dir = Path.expand("lib/xaas/sa2a", File.cwd!())

    callers =
      sa2a_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".ex"))
      |> Enum.flat_map(fn f ->
        source = File.read!(Path.join(sa2a_dir, f))

        # call-site pattern with paren, so docstring mentions (`run/4`) don't count
        if Regex.match?(~r/Xaas\.Actuation\.run\(/, source) do
          [f]
        else
          []
        end
      end)

    assert callers == ["executor.ex"]

    source = File.read!(Path.join(sa2a_dir, "executor.ex"))

    # The authority context construction, pinned in source: the machine-policy
    # map passed as `authority:` to the DO edge carries exactly these keys.
    assert source =~ ~s(kind: "machine_policy")
    assert source =~ ~s(capability: "sa2a_executor")
    assert source =~ ~s(policy: "Xaas.Sa2a.ExecutionPolicy")
    assert source =~ "policy_class: verdict.class_id"
    assert source =~ "admit_receipt_id: verdict.admit_receipt_id"
    assert source =~ "admit_candidate_hash: verdict.admit_candidate_hash"
    assert source =~ "plan_hash: verdict.plan_hash"
    assert source =~ "authorize?: true"
    assert source =~ "idempotency_key: verdict.idempotency_key"
  end

  # -- Route: exactly-one-kind-data-part tuple carrier ----------------------

  defp route_data_part(task) do
    task["input"]
    |> Enum.find(&(&1["kind"] == "data" and &1["data"]["schema"] == Xaas.Sa2a.Route.route_schema()))
  end

  test "task with zero route-schema data parts carries no tuple (missing field refusal)", %{
    task: task
  } do
    bare = Map.put(task, "input", [])

    assert {:refused, {:missing_field, "subject"}} = Xaas.Sa2a.Route.tuple(:task, bare)
  end

  test "task with exactly one kind=data route-schema part yields the tuple", %{task: task} do
    assert {:ok, tuple} = Xaas.Sa2a.Route.tuple(:task, task)
    assert is_binary(tuple["subject"])
    assert is_binary(tuple["capability"])
  end

  test "two route-schema data parts are an ambiguous tuple carrier", %{task: task} do
    part = route_data_part(task)
    doubled = Map.put(task, "input", [part, part])

    assert {:refused, {:ambiguous_tuple_carrier, 2}} = Xaas.Sa2a.Route.tuple(:task, doubled)
  end

  test "conserve wraps the ambiguous carrier in its typed broken_term", %{order: order, task: task} do
    part = route_data_part(task)
    doubled = Map.put(task, "input", [part, part])

    assert {:refused, %{broken_term: "ambiguous_tuple_carrier", hop: :task, reason: 2}} =
             Xaas.Sa2a.Route.conserve(order, doubled, task)
  end

  test "non-data kind parts never carry the tuple", %{task: task} do
    part = route_data_part(task) |> Map.put("kind", "file")
    disguised = Map.put(task, "input", [part])

    assert {:refused, {:missing_field, "subject"}} = Xaas.Sa2a.Route.tuple(:task, disguised)
  end

  # -- PlanningAdvice.order_formal/2 ----------------------------------------

  defp advice_with_candidates(candidates) do
    {:ok, artifact} =
      Xaas.Semantics.ComputationArtifact.new(%{
        artifact_identity: "sha256:w741-model",
        capability_iri: "https://schema.org/Action",
        runtime: "ONNX",
        input_schema_identity: "sha256:in",
        output_schema_identity: "sha256:out",
        input_projection_identity: "sha256:proj",
        deterministic: true
      })

    {:ok, advice} =
      Xaas.Semantics.PlanningAdvice.new(%{
        planning_subject_identity: "sha256:w741-subject",
        formal_projection_identity: "sha256:w741-fond",
        artifact: artifact,
        kind: "FRONTIER",
        candidates: candidates
      })

    advice
  end

  test "order_formal ranks score desc, ties by ref asc, filters to formal set, appends remainder" do
    advice =
      advice_with_candidates([
        %{candidate_ref: "not-formal", score: 99.0},
        %{candidate_ref: "scale-out", score: 0.10},
        %{candidate_ref: "rollback", score: 0.91},
        %{candidate_ref: "failover", score: 0.91}
      ])

    formal = ["restart", "rollback", "failover", "scale-out"]

    # failover < rollback lexicographically, so the 0.91 tie resolves to
    # failover first; "not-formal" is filtered; the unordered formal remainder
    # keeps its original order at the tail.
    assert {:ok, ["failover", "rollback", "scale-out", "restart"]} =
             Xaas.Semantics.PlanningAdvice.order_formal(advice, formal)
  end

  test "order_formal refuses duplicated formal refs" do
    advice = advice_with_candidates([%{candidate_ref: "a", score: 1}])

    assert {:error, :formal_candidate_refs_must_be_unique} =
             Xaas.Semantics.PlanningAdvice.order_formal(advice, ["a", "a"])
  end

  test "order_formal with no advice keeps the formal order" do
    advice = advice_with_candidates([])

    assert {:ok, ["b", "a"]} =
             Xaas.Semantics.PlanningAdvice.order_formal(advice, ["b", "a"])
  end
end
