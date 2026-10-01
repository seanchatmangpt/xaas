defmodule Xaas.Fabric.Planes.Actuation do
  @moduledoc """
  `capability://agent/actuate`: the only plane that crosses DO. It reuses the existing, receipted
  XaaS -> CASTLE bridge (`Xaas.Castle.run/2`: durable outer admission, construct checkpoint,
  CASTLE BRCE PREPARE -> DO -> OUTCOME, sealed outer receipt). Replays of one idempotency key
  never DO twice.

  opts: `:intent` (CASTLE POWL intent map, required), `:allowed_authorities`, `:castle` (extra
  opts for `Xaas.Castle.run/2`).
  """
  @behaviour Xaas.Fabric.Plane

  alias Xaas.Operations.ActuationReceipt

  @impl true
  def contract,
    do: %{
      uri: "capability://agent/actuate",
      semantic_id: "agent.actuate.castle-brce.v1",
      realization: "xaas-castle-bridge",
      ceiling: :do
    }

  @impl true
  def call(:construct, env, facts, opts) do
    # Selection: the requesting authority must be one this actuator is qualified for.
    if env.authority in Keyword.get(opts, :allowed_authorities, []),
      do: {:ok, Map.put(facts, "actuation.selected", true)},
      else: {:error, {:authority_refusal, :actor_not_authorized}}
  end

  def call(:execute, env, facts, opts) do
    castle_opts =
      Keyword.merge(
        [
          idempotency_key: "fabric-#{env.operation_id}",
          authority: %{kind: "xaas_reactor", source: "xaas_fabric", scope: "castle.run"}
        ],
        Keyword.get(opts, :castle, [])
      )

    case Xaas.Castle.run(Keyword.fetch!(opts, :intent), castle_opts) do
      {:ok, result} -> {:ok, Map.put(facts, "actuation.result", result)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Independent observation: the durable outer receipt row, not the bridge's own return value.
  def call(:observe, _env, facts, _opts) do
    id = get_in(facts, ["actuation.result", Access.key(:receipt), Access.key(:id)])
    rows = Ash.read!(ActuationReceipt, authorize?: false)
    row = Enum.find(rows, &(&1.id == id))
    {:ok, Map.put(facts, "actuation.observed", %{"receipt_durable" => row != nil, "status" => row && row.status})}
  end

  def call(_stage, _env, _facts, _opts), do: {:error, :unsupported}
end
