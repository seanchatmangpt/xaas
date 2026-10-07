defmodule Xaas.Fabric.Planes.Evidence do
  @moduledoc """
  `capability://evidence/attest` over `AshAffidavit.call/2` (`assemble` then `verify`).
  A receipt that does not verify yields `{:error, ...}`; execution without a receipt therefore
  has no standing.

  opts: `:affidavit` (opts to `AshAffidavit.call/2`), `:withhold` (true: refuse to receipt).
  """
  @behaviour Xaas.Fabric.Plane

  @impl true
  def contract,
    do: %{
      uri: "capability://evidence/attest",
      semantic_id: "evidence.attest.chain.v1",
      realization: "ash-affidavit",
      ceiling: :observe
    }

  @impl true
  def call(:observe, env, facts, _opts) do
    # Pre-actuation binding: envelope identity + law decision, committed before DO.
    payload = "#{inspect(env.operation_id)}|#{facts["law.decision"]}"

    case affidavit(%{"op" => "commit", "payload" => payload}, []) do
      {:ok, %{"commitment" => c}} -> {:ok, Map.put(facts, "evidence.pre", c)}
      other -> {:error, other}
    end
  end

  def call(:receipt, env, facts, opts) do
    if Keyword.get(opts, :withhold, false) do
      {:error, {:evidence_insufficient, :withheld}}
    else
      events =
        [
          {"projected", "rows:#{facts["witness"].result_sha256}"},
          {"admitted", "law:#{facts["law.decision"]}"},
          {"executed", "do:#{inspect(facts["actuation.result"])}"}
        ]
        |> Enum.map(fn {type, payload} ->
          %{
            "event_type" => type,
            "objects" => ["op:payment:#{env.operation_id}"],
            "payload" => payload
          }
        end)

      case affidavit(%{"op" => "assemble", "events" => events}, Keyword.get(opts, :affidavit, [])) do
        {:ok, %{"receipt" => receipt}} -> {:ok, Map.put(facts, "evidence.receipt", receipt)}
        other -> {:error, other}
      end
    end
  end

  def call(:replay, _env, facts, opts) do
    case affidavit(
           %{"op" => "verify", "receipt" => facts["evidence.receipt"]},
           Keyword.get(opts, :affidavit, [])
         ) do
      {:ok, %{"accepted" => true}} -> :ok
      {:ok, other} -> {:error, {:evidence_insufficient, other["reason"] || :not_accepted}}
      other -> {:error, other}
    end
  end

  def call(_stage, _env, _facts, _opts), do: {:error, :unsupported}

  # apply/3: AshAffidavit is an optional, test/dev-only dependency.
  defp affidavit(request, opts), do: apply(AshAffidavit, :call, [request, opts])
end
