defmodule Xaas.Ultracode.CapabilityResolverExecutionTest do
  @moduledoc """
  Chicago qualification of the capability court's CLOSURE + deterministic
  execution, against real sandboxed Postgres and the real `Local` source
  (no hermetic source for the reuse path): a completed `Run` with a real
  `capability_id` (created through `Run :create`, opened/closed through
  the admitted `ItemRuns` edges, sealed through `Receipt :seal`) is the
  prior subject a `:reuse` verdict must bind.

  The frontier dispatcher passed to `Autonomic.resolve_and_dispatch/3` is
  a REAL function that `flunk`s -- if the court let a satisfied item reach
  the coding stage, the test fails by construction. The anti-vacuity twin
  removes the witness and proves the same dispatcher IS reached.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Ultracode.{Autonomic, CapabilityResolver, Epoch, ItemRuns, Receipt, Run}
  alias Xaas.Ultracode.CapabilityResolver.Execution

  @capability "recipe:mix-format"

  defmodule PackComposeSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx),
      do:
        {:ok,
         [
           %{capability_id: "ingest:normalize", satisfies: ["req-1"], ggen_pack: "ingest-pack"},
           %{capability_id: "report:aggregate", satisfies: ["req-2"]}
         ]}
  end

  setup do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)

    saved =
      for key <- [:ultracode_capability_sources, :ultracode_sa2a_capability_endpoint],
          into: %{},
          do: {key, Application.fetch_env(:xaas, key)}

    # The DEFAULT, derived source set: no explicit sources, sa2a unset.
    Application.delete_env(:xaas, :ultracode_capability_sources)
    Application.delete_env(:xaas, :ultracode_sa2a_capability_endpoint)

    on_exit(fn ->
      for {key, value} <- saved do
        case value do
          {:ok, v} -> Application.put_env(:xaas, key, v)
          :error -> Application.delete_env(:xaas, key)
        end
      end
    end)

    tmp = Path.join(System.tmp_dir!(), "resolver-exec-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    %{ctx: %{out_dir: tmp, ledger: Path.join(tmp, "ledger.ndjson")}, tmp: tmp}
  end

  defp sys_actor, do: Xaas.SystemAuthority.new(:ultracode_reactor)

  defp completed_run!(capability_id) do
    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "resolver execution prior subject", max_cycles: 1, capability_id: capability_id},
        authorize?: false
      )
      |> Ash.create!()

    {:ok, _} = ItemRuns.open!(run.id)

    epoch =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "xaas-autonomic:resolver-exec##{System.unique_integer([:positive])}",
          state: :completed
        },
        authorize?: false
      )
      |> Ash.create!()

    Receipt
    |> Ash.Changeset.for_create(:seal, %{
      epoch_id: epoch.id,
      subject: epoch.exact_subject,
      outcome: :alive,
      evidence: %{"head_verified" => true, "fabric_verifier" => %{"status" => "pass"}},
      sealed_at: DateTime.utc_now()
    })
    |> Ash.create!(actor: sys_actor())

    {:ok, {:transitioned, :completed}} = ItemRuns.close_attempt!(run, epoch)
    run
  end

  defp lines(tmp) do
    Path.join(tmp, "capability-resolutions.ndjson")
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  defp flunking_dispatcher do
    fn frontier -> flunk("frontier dispatcher reached for #{inspect(frontier)}") end
  end

  test "sa2a unconfigured + local match => :reuse EXECUTES as :known_replay; no worker", %{
    ctx: ctx,
    tmp: tmp
  } do
    run = completed_run!(@capability)
    item = %{"id" => "w-reuse", "capability_id" => @capability}

    assert [result] = Autonomic.resolve_and_dispatch([item], ctx, flunking_dispatcher())

    assert result.item == "w-reuse"
    assert result.status == :satisfied_existing
    assert result.outcome == :known_replay
    assert result.replay_of == "run:#{run.id}"

    [resolution, execution] = lines(tmp)

    assert resolution["class"] == "reuse"
    # The unconfigured sa2a witness is RECORDED, but uncounted: it did not
    # fail the closure.
    assert resolution["sources_queried"]["sa2a"]["status"] == "skipped"
    assert resolution["sources_queried"]["sa2a"]["counted"] == false
    assert resolution["sources_queried"]["local"]["status"] == "ok"
    assert [%{"run_id" => run_id}] = resolution["candidate_capabilities"]
    assert run_id == run.id

    assert execution["schema"] == Execution.schema()
    assert execution["outcome"] == "known_replay"
    assert execution["subject"] == "run:#{run.id}"
    assert execution["standing"] == "PARTIAL_ALIVE"
    assert execution["replay"]["selected_capabilities"] == [@capability]
    assert execution["authority"] =~ "capability-resolution-court"
    assert execution["consequence"] =~ "no_worker_dispatched"

    assert File.read!(ctx.ledger) =~ "capability_execution"
  end

  test "anti-vacuity: with NO completed-run witness the same item reaches the dispatcher", %{
    ctx: ctx,
    tmp: tmp
  } do
    item = %{"id" => "w-new", "capability_id" => @capability}
    parent = self()

    dispatcher = fn frontier ->
      send(parent, {:dispatched, Enum.map(frontier, & &1["id"])})
      Enum.map(frontier, &%{item: &1["id"], status: :done, attempts: 1, history: []})
    end

    assert [%{item: "w-new", status: :done}] =
             Autonomic.resolve_and_dispatch([item], ctx, dispatcher)

    assert_received {:dispatched, ["w-new"]}
    # Frontier => no execution record, only the resolution receipt.
    assert [%{"class" => "frontier"}] = lines(tmp)
  end

  test "a CONFIGURED sa2a endpoint on a closed localhost port fail-closes to :unresolved", %{
    ctx: ctx
  } do
    completed_run!(@capability)
    Application.put_env(:xaas, :ultracode_sa2a_capability_endpoint, "http://127.0.0.1:1/sa2a")

    assert {%{"local" => _, "sa2a" => _}, uncounted} = CapabilityResolver.configured_sources()
    assert uncounted == %{}

    item = %{"id" => "w-closed", "capability_id" => @capability}

    assert [result] = Autonomic.resolve_and_dispatch([item], ctx, flunking_dispatcher())
    assert result.status == :blocked
    assert result.reason == "capability_resolution_unresolved"
  end

  test "a compose naming a ggen pack is receipted {:unsupported, :executor_pending}", %{
    ctx: ctx,
    tmp: tmp
  } do
    Application.put_env(:xaas, :ultracode_capability_sources, %{"fleet" => PackComposeSource})
    item = %{"id" => "w-compose", "required_capabilities" => ["req-1", "req-2"]}

    assert [result] = Autonomic.resolve_and_dispatch([item], ctx, flunking_dispatcher())
    assert result.outcome == {:unsupported, :executor_pending}

    [resolution, execution] = lines(tmp)
    assert resolution["class"] == "compose"
    assert execution["outcome"] == "unsupported:executor_pending"
    assert execution["pack_ids"] == ["ingest-pack"]
    assert execution["standing"] == "UNSUPPORTED"
  end
end
