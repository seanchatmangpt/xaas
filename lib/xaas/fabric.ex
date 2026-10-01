defmodule Xaas.Fabric do
  @moduledoc """
  CASTLE capability fabric: thin composition over the existing `ash_*` planes and the
  XaaS -> CASTLE bridge. CASTLE supplies the envelope (product intent); XaaS resolves each
  `capability://` URI to an ordered list of `{Plane module, opts}` realizations and drives

      OBSERVE (project, process) -> CONSTRUCT (law) -> evidence pre-bind -> select actor
        -> DO (exactly once, never failed over) -> observe -> receipt -> process conformance -> replay

  Standing is derived, never asserted: `:evidenced` needs a verified receipt AND a conforming
  process history; `:refused` for semantic/authority refusals; otherwise `:unknown`.
  Transient `:realization_failed` closes one edge and the next realization serves.
  """

  alias Xaas.Fabric.{Failure, Plane}

  @planes ~w(projection process law evidence actuation)a

  defstruct stages: [:requested],
            standing: :unknown,
            refusal: nil,
            do_crossings: 0,
            served_by: %{},
            facts: %{}

  @type realization :: {module(), keyword()}

  @spec run(map(), %{atom() => [realization()]}) :: %__MODULE__{}
  def run(env, planes) when is_map(env) and is_map(planes) do
    out = %__MODULE__{facts: %{"envelope" => env}}

    case missing(planes) do
      nil ->
        case pipeline(env, planes, out) do
          {:ok, out} -> out
          {:error, failure, out} -> finish_failed(failure, out)
        end

      plane ->
        finish_failed(Failure.normalize({:capability_unavailable, plane}, :fabric), out)
    end
  end

  defp finish_failed(failure, out) do
    standing = if failure.class in [:semantic_refusal, :authority_refusal, :process_invalid], do: :refused, else: out.standing
    %{out | refusal: failure, standing: standing}
  end

  defp missing(planes), do: Enum.find(@planes, &(Map.get(planes, &1, []) == []))

  defp pipeline(env, planes, out) do
    with {:ok, out} <- step(out, env, planes, :projection, :observe),
         {:ok, out} <- event(out, env, planes, "requested"),
         {:ok, out} <- construct(out, env, planes),
         {:ok, out} <- event(out, env, planes, "constructed"),
         {:ok, out} <- step(out, env, planes, :evidence, :observe),
         {:ok, out} <- step(out, env, planes, :actuation, :construct),
         {:ok, out} <- execute(out, env, planes),
         {:ok, out} <- step(out, env, planes, :actuation, :observe),
         out = push(out, :observed),
         {:ok, out} <- event(out, env, planes, "executed"),
         {:ok, out} <- step(out, env, planes, :evidence, :receipt),
         out = push(out, :receipted),
         {:ok, out} <- event(out, env, planes, "receipted"),
         {:ok, out} <- step(out, env, planes, :process, :receipt) do
      conforms = get_in(out.facts, ["process.conformance", "conforms"]) == true
      out = if conforms, do: push(out, :reconciled), else: out

      verified = match?({:ok, _}, drive(out, env, planes, :evidence, :replay))
      {:ok, if(verified and conforms, do: %{out | standing: :evidenced}, else: out)}
    end
  end

  defp push(out, stage), do: %{out | stages: out.stages ++ [stage]}

  defp event(out, env, planes, kind) do
    out = %{out | facts: Map.put(out.facts, "process.event", kind)}
    step(out, env, planes, :process, :observe)
  end

  defp construct(out, env, planes) do
    case step(out, env, planes, :law, :construct) do
      {:ok, out} -> {:ok, push(push(out, :qualified), :constructed)}
      {:error, failure, out} ->
        {_, out} = event_ignore(out, env, planes, "refused")
        {:error, failure, out}
    end
  end

  defp event_ignore(out, env, planes, kind) do
    case event(out, env, planes, kind) do
      {:ok, out} -> {:ok, out}
      {:error, _, out} -> {:error, out}
    end
  end

  # DO: exactly one realization, one attempt; a failure here is never failed over.
  defp execute(out, env, planes) do
    out = %{out | do_crossings: out.do_crossings + 1}

    case step(out, env, planes, :actuation, :execute, failover?: false) do
      {:ok, out} -> {:ok, push(out, :executed)}
      err -> err
    end
  end

  defp step(out, env, planes, plane, stage, opts \\ []) do
    case drive(out, env, planes, plane, stage, opts) do
      {:ok, {facts, served}} -> {:ok, %{out | facts: facts, served_by: Map.put(out.served_by, plane, served)}}
      {:error, failure} -> {:error, failure, out}
    end
  end

  defp drive(out, env, planes, plane, stage, opts \\ []) do
    failover? = Keyword.get(opts, :failover?, true)
    try_each(Map.fetch!(planes, plane), out, env, stage, failover?, nil)
  end

  defp try_each([], _out, _env, _stage, _failover?, last), do: {:error, last}

  defp try_each([{mod, opts} | rest], out, env, stage, failover?, _last) do
    contract = mod.contract()

    cond do
      not Plane.permit(contract, stage) ->
        {:error, Failure.normalize({:authority_refusal, "#{stage}_exceeds_#{contract.ceiling}"}, contract.realization |> String.to_atom())}

      true ->
        case mod.call(stage, env, out.facts, opts) do
          {:ok, facts} when is_map(facts) -> {:ok, {facts, contract.realization}}
          :ok -> {:ok, {out.facts, contract.realization}}
          {:error, raw} ->
            failure = Failure.normalize(raw, String.to_atom(contract.realization))
            if failover? and failure.transient? and rest != [],
              do: try_each(rest, out, env, stage, failover?, failure),
              else: {:error, failure}
        end
    end
  end
end
