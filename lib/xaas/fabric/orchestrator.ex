defmodule Xaas.Fabric.Orchestrator do
  @moduledoc """
  Drives OBSERVE -> CONSTRUCT -> DO -> RECEIPT -> STANDING over a registry using URIs only.
  CASTLE supplies the envelope (product intent); XaaS owns this runtime composition.

  Stages are reported separately. `standing: :alive` needs a verified receipt and a conforming
  process history. DO never falls over to another realization (no double actuation).
  """

  alias Xaas.Fabric.{Capability, Contract, Registry}

  @uris %{
    projection: "capability://projection/map",
    process: "capability://process/conformance",
    law: "capability://law/admit",
    evidence: "capability://evidence/attest",
    actuation: "capability://agent/actuate"
  }
  def uris, do: @uris

  defstruct stages: [:requested],
            standing: :unknown,
            refusal: nil,
            do_crossings: 0,
            receipt: nil,
            conformance: nil,
            served_by: %{},
            facts: %{}

  @spec run(Registry.t(), map()) :: %__MODULE__{}
  def run(%Registry{} = reg, env) do
    out = %__MODULE__{facts: %{"envelope.digest" => digest(env)}}

    case pipeline(reg, env, out) do
      {:ok, out} ->
        out

      {:error, {class, detail}, out} ->
        standing = if class in [:semantic_refusal, :authority_refusal, :process_invalid], do: :refused, else: out.standing
        %{out | refusal: "REFUSED:#{class |> to_string() |> String.upcase()}:#{inspect(detail)}", standing: standing}
    end
  end

  def digest(env), do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, :erlang.term_to_binary(env, [:deterministic])), case: :lower)

  # Try realizations in order; DO is tried once only.
  defp drive(reg, uri, op, out, fun) do
    case Registry.resolve(reg, uri) do
      [] -> {:error, {:capability_unavailable, uri}, out}
      mods -> try_mods(mods, uri, op, out, fun, {:capability_unavailable, uri})
    end
  end

  defp try_mods([], _uri, _op, out, _fun, last), do: {:error, last, out}

  defp try_mods([mod | rest], uri, op, out, fun, _last) do
    contract = mod.describe()

    with :ok <- Contract.permit(contract, op),
         {:ok, result} <- fun.(mod) do
      {:ok, result, %{out | served_by: Map.put(out.served_by, uri, contract.realization)}}
    else
      {:error, {class, _} = e} ->
        if op != :do and Capability.falls_over?(class),
          do: try_mods(rest, uri, op, out, fun, e),
          else: {:error, e, out}
    end
  end

  defp facts_step(reg, uri, op, env, out, fname) do
    case drive(reg, uri, op, out, fn mod -> apply(mod, fname, [env, out.facts]) end) do
      {:ok, facts, out} -> {:ok, %{out | facts: facts}}
      {:error, _, _} = err -> err
    end
  end

  defp event(reg, env, out, kind) do
    out = %{out | facts: Map.put(out.facts, "process.event", kind)}
    facts_step(reg, @uris.process, :observe, env, out, :observe)
  end

  defp pipeline(reg, env, out) do
    missing = Enum.find(Map.values(@uris), &(Registry.resolve(reg, &1) == []))

    if missing do
      {:error, {:capability_unavailable, missing}, out}
    else
      with {:ok, out} <- facts_step(reg, @uris.projection, :observe, env, out, :observe),
           {:ok, out} <- event(reg, env, out, "requested"),
           {:ok, _, out} <- drive(reg, @uris.law, :select, out, fn m -> with :ok <- m.qualify(env), do: {:ok, :ok} end),
           out = push(out, :qualified),
           {:ok, out} <- construct(reg, env, out),
           out = push(out, :constructed),
           {:ok, out} <- event(reg, env, out, "constructed"),
           {:ok, out} <- facts_step(reg, @uris.evidence, :observe, env, out, :observe),
           {:ok, out} <- facts_step(reg, @uris.actuation, :select, env, out, :select),
           {:ok, out} <- execute_do(reg, env, out),
           out = push(out, :executed),
           {:ok, out} <- facts_step(reg, @uris.actuation, :observe, env, out, :observe),
           out = push(out, :observed),
           {:ok, out} <- event(reg, env, out, "executed"),
           {:ok, out} <- receipt(reg, env, out),
           out = push(out, :receipted),
           {:ok, out} <- event(reg, env, out, "receipted") do
        finish(reg, env, out)
      end
    end
  end

  defp push(out, stage), do: %{out | stages: out.stages ++ [stage]}

  defp construct(reg, env, out) do
    case facts_step(reg, @uris.law, :construct, env, out, :construct) do
      {:ok, out} -> {:ok, out}
      {:error, e, out} -> _ = event(reg, env, out, "refused"); {:error, e, out}
    end
  end

  defp execute_do(reg, env, out) do
    out = %{out | do_crossings: out.do_crossings + 1}
    facts_step(reg, @uris.actuation, :do, env, out, :execute)
  rescue
    _ -> {:error, {:realization_failed, :execute}, out}
  end

  defp receipt(reg, env, out) do
    case drive(reg, @uris.evidence, :observe, out, fn m -> m.receipt(env, out.facts) end) do
      {:ok, receipt, out} -> {:ok, %{out | receipt: receipt}}
      err -> err
    end
  end

  defp finish(reg, env, out) do
    {:ok, conf, out} = drive_ok(reg, @uris.process, out, fn m -> m.receipt(env, out.facts) end)
    conforms = conf["conforms"] == true
    out = %{out | conformance: conf}
    out = if conforms, do: push(out, :reconciled), else: out

    valid =
      match?({:ok, _, _}, drive(reg, @uris.evidence, :observe, out, fn m -> with :ok <- m.replay(env, out.receipt), do: {:ok, :ok} end))

    {:ok, if(valid and conforms, do: %{out | standing: :alive}, else: out)}
  end

  defp drive_ok(reg, uri, out, fun) do
    case drive(reg, uri, :observe, out, fun) do
      {:ok, _, _} = ok -> ok
      {:error, _, _} -> {:ok, %{"conforms" => false}, out}
    end
  end

  @doc "Semantic replay: law decision + receipt verification. Never re-actuates."
  def replay(%Registry{} = reg, env, receipt) do
    r = fn uri ->
      case drive(reg, uri, :observe, %__MODULE__{}, fn m -> with :ok <- m.replay(env, receipt), do: {:ok, :ok} end) do
        {:ok, _, _} -> :ok
        {:error, e, _} -> {:error, e}
      end
    end

    %{same_decision: r.(@uris.law) == :ok, receipt_valid: r.(@uris.evidence) == :ok}
  end
end
