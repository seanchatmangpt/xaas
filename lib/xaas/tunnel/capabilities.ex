defmodule Xaas.Tunnel.Capabilities do
  @moduledoc """
  Capability allowlist of the bounded runtime fabric (`/internal-api/fabric`,
  protocol `xaas-fabric/1`).

  The fabric exposes exactly three capabilities. `actuate` (the DO verb served to
  ZCode workers on `/internal-api/execution/mcp`) is refused here by authority
  ceiling, permanently: a fabric principal constructs and reads, it never
  actuates. Every other verb fails closed as `capability_not_admitted`.

  The source of truth for the three individuals is `priv/tunnel/ontology.ttl`;
  `test/xaas/tunnel/capabilities_ontology_test.exs` asserts `allowlist/0` equals
  the ontology's admitted set, so the two cannot drift silently.

  HANDWRITTEN.md: UNSUPPORTED(generator-capability) -- no admitted pack renders
  a pure Elixir capability gate from the tunnel ontology.
  """

  @allowlist ~w(fabric.probe run.submit epoch.receipts)
  @refused %{"actuate" => :authority_ceiling}

  @type refusal ::
          {:capability_not_admitted, String.t()} | {:authority_ceiling, String.t()}

  @doc "The admitted capability verbs, in declaration order."
  @spec allowlist() :: [String.t()]
  def allowlist, do: @allowlist

  @doc "Verbs refused by design, with their typed reason."
  @spec refused() :: %{String.t() => atom()}
  def refused, do: @refused

  @doc "Admit one verb; unknown verbs fail closed."
  @spec admit(term()) :: :ok | {:refused, refusal()}
  def admit(verb) when is_binary(verb) do
    cond do
      Map.has_key?(@refused, verb) -> {:refused, {Map.fetch!(@refused, verb), verb}}
      verb in @allowlist -> :ok
      true -> {:refused, {:capability_not_admitted, verb}}
    end
  end

  def admit(verb), do: {:refused, {:capability_not_admitted, inspect(verb)}}

  @doc """
  Admit a requested set. Order of `admitted` follows the request; duplicates are
  collapsed. A non-list request admits nothing.
  """
  @spec admit_set(term()) :: %{admitted: [String.t()], refused: [{String.t(), atom()}]}
  def admit_set(verbs) when is_list(verbs) do
    verbs
    |> Enum.uniq()
    |> Enum.reduce(%{admitted: [], refused: []}, fn verb, acc ->
      case admit(verb) do
        :ok -> %{acc | admitted: [verb | acc.admitted]}
        {:refused, {reason, name}} -> %{acc | refused: [{name, reason} | acc.refused]}
      end
    end)
    |> then(&%{admitted: Enum.reverse(&1.admitted), refused: Enum.reverse(&1.refused)})
  end

  def admit_set(_), do: %{admitted: [], refused: []}
end
