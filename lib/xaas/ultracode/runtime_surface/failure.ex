defmodule Xaas.Ultracode.RuntimeSurface.Failure do
  @moduledoc """
  The agent-facing failure vocabulary of the UltraCode runtime surface.

  Every error an agent sees through the semantic ports is one of `codes/0`,
  rendered as `%{"code" => "STALE_SUBJECT", "details" => map}`. Provider- or
  transport-specific detail stays inside `"details"`; the code itself never
  names a provider.
  """

  @codes [
    :no_capability,
    :ambiguous_capability,
    :capability_unavailable,
    :unauthorized,
    :work_not_found,
    :stale_subject,
    :invalid_transition,
    :provenance_mismatch,
    :conflicting_replay,
    :forbidden_external_semantic_edge
  ]

  @type t :: %{String.t() => String.t() | map()}

  @doc "The closed failure-code vocabulary."
  @spec codes() :: [atom()]
  def codes, do: @codes

  @doc "Build a failure map; raises `ArgumentError` on a code outside `codes/0`."
  @spec new(atom(), map()) :: t()
  def new(code, details \\ %{}) when is_map(details) do
    unless code in @codes do
      raise ArgumentError, "unknown runtime surface failure code: #{inspect(code)}"
    end

    %{"code" => code |> Atom.to_string() |> String.upcase(), "details" => details}
  end

  @doc "Map an internal error term to a failure map."
  @spec from_term(term()) :: t()
  def from_term(%{"code" => code, "details" => _} = failure) when is_binary(code), do: failure

  def from_term({:idempotency_conflict, d}), do: new(:conflicting_replay, details(d))
  def from_term({:stale_subject, d}), do: new(:stale_subject, details(d))
  def from_term({:provenance_mismatch, d}), do: new(:provenance_mismatch, details(d))

  def from_term({:forbidden_external_semantic_edge, d}),
    do: new(:forbidden_external_semantic_edge, details(d))

  def from_term({:refused_no_authority, tool}),
    do: new(:unauthorized, %{"refusal" => "refused_no_authority", "tool" => to_string(tool)})

  def from_term(:delegated_actuation_requires_authority_evidence),
    do: new(:unauthorized, %{"refusal" => "delegated_actuation_requires_authority_evidence"})

  def from_term(reason)
      when reason in [:lease_expired, :unknown_lease, :not_found, :lease_not_live],
      do: new(:work_not_found, %{"reason" => Atom.to_string(reason)})

  def from_term({reason, d}) when reason in [:lease_expired, :lease_not_live, :no_lease],
    do: new(:work_not_found, %{"reason" => Atom.to_string(reason), "detail" => inspect(d)})

  def from_term({:unregistered_actuation, target}),
    do: new(:unauthorized, %{"reason" => "unregistered_actuation", "target" => inspect(target)})

  def from_term({:sa2a_transport, d}),
    do: new(:capability_unavailable, %{"reason" => "sa2a_transport", "detail" => inspect(d)})

  def from_term({:sa2a_status, d}),
    do: new(:capability_unavailable, %{"reason" => "sa2a_status", "detail" => inspect(d)})

  def from_term(:sa2a_body_malformed),
    do: new(:capability_unavailable, %{"reason" => "sa2a_body_malformed"})

  def from_term({:raised, kind, d}),
    do:
      new(:capability_unavailable, %{
        "reason" => "raised",
        "kind" => inspect(kind),
        "detail" => inspect(d)
      })

  def from_term({:invalid_endpoint_config, d}),
    do:
      new(:capability_unavailable, %{
        "reason" => "invalid_endpoint_config",
        "detail" => inspect(d)
      })

  def from_term({:invalid_transition, d}), do: new(:invalid_transition, details(d))

  def from_term(term), do: new(:capability_unavailable, %{"term" => inspect(term)})

  defp details(d) when is_map(d), do: d
  defp details(d) when is_list(d), do: %{"items" => d}
  defp details(d), do: %{"detail" => inspect(d)}
end
