defmodule Xaas.Sa2a.RouteTest do
  @moduledoc """
  G5 SA2A conservation court for `Xaas.Sa2a.Route` (GC-FRI-0800).

  Chicago style, no test doubles:

    * the sJira hop is the committed order fixture
      `test/fixtures/sa2a_route/work_order.json` (wo.json row + tuple fields);
    * the SA2A hop is `test/fixtures/sa2a_route/sa2a_task.json`, produced by
      running the real `GgenIgniter.SemanticA2A.task_from_work_order/2` via
      `scripts/gen_sa2a_route_fixture.exs` (provenance in
      `sa2a_task.provenance.json`), never hand-typed;
    * the XaaS hop is an epoch contract admitted by the real
      `Xaas.Ultracode.SemanticWork.admit/1` inside `Route.tuple/1`;
    * the digest contract is cross-checked against a real `python3`
      subprocess computing the contract's canonical JSON independently;
    * the capability registry is the real application env key
      `:ultracode_construction_recipes`, put in setup and restored on exit.
  """
  use ExUnit.Case, async: false

  alias Xaas.Sa2a.Route

  @fixture_dir Path.expand("../../fixtures/sa2a_route", __DIR__)
  @registry_key :ultracode_construction_recipes

  # contract field -> key in each hop's carrier
  @order_keys %{
    "subject" => "subject",
    "postcondition" => "postcondition",
    "capability" => "requires_capability",
    "evidence_ceiling" => "evidence_ceiling",
    "authority_ceiling" => "authority_ceiling",
    "consequence_class" => "consequence_class",
    "exclusions" => "exclusions"
  }

  @task_keys %{
    "subject" => "subject",
    "postcondition" => "postcondition",
    "capability" => "requiresCapability",
    "evidence_ceiling" => "evidenceCeiling",
    "authority_ceiling" => "authorityCeiling",
    "consequence_class" => "consequenceClass",
    "exclusions" => "exclusions"
  }

  @hops [:order, :task, :epoch]

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
    %{order: order, task: task, epoch: epoch_contract(order, task)}
  end

  describe "the generated SA2A hop" do
    test "is the real ggen_igniter projection of the fixture order", %{order: order, task: task} do
      provenance = read_json!("sa2a_task.provenance.json")

      assert provenance["producer"] == "GgenIgniter.SemanticA2A.task_from_work_order/2"
      assert provenance["generator"] == "scripts/gen_sa2a_route_fixture.exs"
      assert provenance["ggen_igniter_head"] =~ ~r/\A[0-9a-f]{40}\z/
      assert task["taskId"] == "urn:" <> order["replay_identity"]
      assert task["contextId"] == provenance["work_order_digest"]
      assert task["metadata"]["authority"] == "NONE"
      assert task["metadata"]["baseSha"] == order["base_sha"]
      assert task["metadata"]["schema"] == Route.route_schema()
    end
  end

  describe "conservation" do
    test "all three hops normalize to one tuple with one digest", ctx do
      expected = %{
        "subject" => ctx.order["subject"],
        "postcondition" => ctx.order["postcondition"],
        "capability" => "recipe:mix-format",
        "evidence_ceiling" => "EXECUTED_VERIFIED",
        "authority_ceiling" => "CONSTRUCT",
        "consequence_class" => "postcondition",
        "exclusions" => Enum.sort(ctx.order["exclusions"])
      }

      assert {:ok, ^expected} = Route.tuple(ctx.order)
      assert {:ok, ^expected} = Route.tuple(ctx.task)
      assert {:ok, ^expected} = Route.tuple(ctx.epoch)

      digests = Enum.map(@hops, fn hop -> ctx |> carrier(hop) |> digest!() end)
      assert [digest, digest, digest] = digests
      assert digest =~ ~r/\Asha256:[0-9a-f]{64}\z/
      assert Route.conserve(ctx.order, ctx.task, ctx.epoch) == :ok
    end

    test "the epoch contract conserves with atom keys and reordered exclusions", ctx do
      bridge =
        ctx.epoch["bridge"]
        |> Map.update!("exclusions", &Enum.reverse/1)
        |> Map.new(fn {key, value} -> {String.to_atom(key), value} end)

      epoch = Map.put(ctx.epoch, "bridge", bridge)

      assert Route.conserve(ctx.order, ctx.task, epoch) == :ok
    end

    test "an epoch carrying its capability only in the bridge conserves", ctx do
      epoch =
        ctx.epoch
        |> Map.delete("capability")
        |> put_in(["bridge", "requires_capability"], ctx.order["requires_capability"])

      assert Route.conserve(ctx.order, ctx.task, epoch) == :ok
    end

    test "an epoch whose bridge capability disagrees with its executed capability is refused",
         ctx do
      epoch = put_in(ctx.epoch, ["bridge", "requires_capability"], "recipe:ggen-sync")

      assert Route.tuple(epoch) == {:refused, {:invalid_field, "capability"}}

      assert Route.conserve(ctx.order, ctx.task, epoch) ==
               {:refused, %{broken_term: "admission_vacuous", field: "capability"}}
    end

    test "a task without the route-tuple data part conserves nothing", ctx do
      bare = Map.put(ctx.task, "input", [])

      assert Route.conserve(ctx.order, bare, ctx.epoch) ==
               {:refused, %{broken_term: "admission_vacuous", field: "subject"}}
    end

    test "an epoch contract SemanticWork refuses is refused at the epoch hop", ctx do
      epoch = Map.put(ctx.epoch, "base_sha", "not-a-sha")

      assert {:refused, %{broken_term: "epoch_contract_refused", hop: :epoch, reason: reason}} =
               Route.conserve(ctx.order, ctx.task, epoch)

      assert reason == {:refused_semantic_work, {:invalid, :base_sha}}
    end

    test "a representation of the wrong hop is refused", ctx do
      assert Route.conserve(ctx.order, ctx.order, ctx.epoch) ==
               {:refused, %{broken_term: "admission_vacuous", field: "subject"}}

      assert Route.conserve(ctx.order, ctx.task, :not_a_map) ==
               {:refused, %{broken_term: "unrecognized_representation", hop: :epoch}}
    end
  end

  describe "mutation table: one field changed at one hop is refused naming the field" do
    for hop <- [:order, :task, :epoch], field <- Route.fields() do
      @hop hop
      @field field
      test "#{field} mutated at the #{hop} hop", ctx do
        mutated = mutate(ctx, @hop, @field, &mutation(@field, &1))

        refute digest!(carrier(mutated, @hop)) == digest!(carrier(ctx, @hop))

        assert Route.conserve(mutated.order, mutated.task, mutated.epoch) ==
                 {:refused, %{broken_term: "admission_vacuous", field: @field}}
      end
    end
  end

  describe "drop table: one field removed at one hop is refused naming the field" do
    for hop <- [:order, :task, :epoch], field <- Route.fields() do
      @hop hop
      @field field
      test "#{field} dropped at the #{hop} hop", ctx do
        dropped = mutate(ctx, @hop, @field, fn _ -> :drop end)

        assert Route.conserve(dropped.order, dropped.task, dropped.epoch) ==
                 {:refused, %{broken_term: "admission_vacuous", field: @field}}
      end
    end
  end

  describe "digest contract" do
    test "equals an independent python3 canonical-JSON sha256", %{order: order} do
      python = System.find_executable("python3")
      assert python, "python3 is required for the cross-implementation digest check"
      {:ok, tuple} = Route.tuple(order)

      program = """
      import hashlib, json, sys
      t = json.load(open(sys.argv[1], encoding="utf-8"))
      t["exclusions"] = sorted(t["exclusions"])
      b = json.dumps(t, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
      print("sha256:" + hashlib.sha256(b.encode("utf-8")).hexdigest())
      """

      path =
        Path.join(System.tmp_dir!(), "route_tuple_#{System.unique_integer([:positive])}.json")

      File.write!(path, Jason.encode!(tuple))
      on_exit(fn -> File.rm(path) end)

      {out, 0} = System.cmd(python, ["-c", program, path])

      assert String.trim(out) == Route.digest(tuple)
    end

    test "is independent of exclusion order and of extra carrier fields", %{order: order} do
      {:ok, tuple} = Route.tuple(order)
      reordered = Map.update!(tuple, "exclusions", &Enum.reverse/1)

      assert Route.digest(reordered) == Route.digest(tuple)
      assert Route.digest(Map.put(tuple, "evidence_horizon", "ignored")) == Route.digest(tuple)
      refute Route.digest(Map.put(tuple, "subject", "x/y@z#other")) == Route.digest(tuple)
    end
  end

  describe "resolve/1" do
    test "a registered recipe capability resolves to the recipe provider", %{order: order} do
      assert Route.resolve("recipe:mix-format") == {:ok, {"recipe", "mix-format"}}
      assert {:ok, tuple} = Route.tuple(order)
      assert Route.resolve(tuple) == {:ok, {"recipe", "mix-format"}}
    end

    test "keyword and list registries resolve by recipe id or capability_id" do
      Application.put_env(:xaas, @registry_key, [{:"mix-format", [argv: ["mix", "format"]]}])
      assert Route.resolve("recipe:mix-format") == {:ok, {"recipe", "mix-format"}}

      Application.put_env(:xaas, @registry_key, [
        %{"capability_id" => "recipe:mix-format", "id" => "format-drift"}
      ])

      assert Route.resolve("recipe:mix-format") == {:ok, {"recipe", "format-drift"}}
    end

    test "an unknown capability is refused" do
      assert Route.resolve("recipe:ggen-sync") == {:refused, :unregistered_capability}
      assert Route.resolve("zcode:mix-format") == {:refused, :unregistered_capability}
      assert Route.resolve("mix-format") == {:refused, :unregistered_capability}
      assert Route.resolve(nil) == {:refused, :unregistered_capability}
    end

    test "an absent registry refuses every capability" do
      Application.delete_env(:xaas, @registry_key)
      assert Route.resolve("recipe:mix-format") == {:refused, :unregistered_capability}
    end
  end

  # -- helpers ---------------------------------------------------------------

  defp read_json!(name), do: @fixture_dir |> Path.join(name) |> File.read!() |> Jason.decode!()

  # The XaaS hop: a SemanticWork descriptor for the fixture order whose bridge
  # carries the tuple; its provider is the one the capability resolves to.
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
        @order_keys
        |> Map.delete("capability")
        |> Map.values()
        |> Map.new(&{&1, order[&1]})
        |> Map.merge(%{
          "identity" => order["identity"],
          "replay_identity" => order["replay_identity"]
        })
    }
  end

  defp carrier(ctx, :order), do: ctx.order
  defp carrier(ctx, :task), do: ctx.task
  defp carrier(ctx, :epoch), do: ctx.epoch

  defp digest!(representation) do
    {:ok, tuple} = Route.tuple(representation)
    Route.digest(tuple)
  end

  defp mutate(ctx, :order, field, fun),
    do: %{ctx | order: change(ctx.order, @order_keys[field], fun)}

  # the epoch hop carries its capability top-level (the executed sj:capabilityId)
  defp mutate(ctx, :epoch, "capability", fun),
    do: %{ctx | epoch: change(ctx.epoch, "capability", fun)}

  defp mutate(ctx, :epoch, field, fun),
    do: %{ctx | epoch: Map.update!(ctx.epoch, "bridge", &change(&1, @order_keys[field], fun))}

  defp mutate(ctx, :task, field, fun) do
    input =
      Enum.map(ctx.task["input"], fn part ->
        update_in(part, ["data", "tuple"], &change(&1, @task_keys[field], fun))
      end)

    %{ctx | task: Map.put(ctx.task, "input", input)}
  end

  defp change(map, key, fun) do
    case fun.(Map.fetch!(map, key)) do
      :drop -> Map.delete(map, key)
      value -> Map.put(map, key, value)
    end
  end

  defp mutation("exclusions", list), do: list ++ ["no deploy"]
  defp mutation("capability", _), do: "recipe:ggen-sync"
  defp mutation("consequence_class", _), do: "verification"
  defp mutation(_field, value), do: value <> " (mutated)"
end
