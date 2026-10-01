defmodule Xaas.Fabric.Planes.Process do
  @moduledoc """
  `capability://process/conformance`. Events are kept in facts; `:receipt` assembles the observed
  trace with `AshAffidavit` and checks it with the `conform` op against the expected model
  (requested, constructed, executed, receipted). PARTIAL: backed by affidavit's conformance op, not
  `ash_ex4pm`/`Ex4pm.*` (version-pin conflict recorded in the plan).

  opts: `:affidavit`.
  """
  @behaviour Xaas.Fabric.Plane

  @expected ~w(requested constructed executed receipted)

  @impl true
  def contract,
    do: %{
      uri: "capability://process/conformance",
      semantic_id: "process.conformance.trace.v1",
      realization: "affidavit-conform",
      ceiling: :observe
    }

  @impl true
  def call(:observe, _env, facts, _opts) do
    kind = facts["process.event"] || "unknown"
    {:ok, Map.update(facts, "process.events", [kind], &(&1 ++ [kind]))}
  end

  def call(:receipt, env, facts, opts) do
    aopts = Keyword.get(opts, :affidavit, [])
    observed = facts["process.events"] || []

    with {:ok, %{"receipt" => model}} <- assemble(env, @expected, aopts),
         {:ok, %{"receipt" => trace}} <- assemble(env, observed, aopts),
         {:ok, conf} <- apply(AshAffidavit, :call, [%{"op" => "conform", "model" => [model], "trace" => trace}, aopts]) do
      {:ok, Map.put(facts, "process.conformance", %{"conforms" => conf["verdict"] in ["conforms", "conformant", "ok", true] or conf["fitness"] == 1.0, "raw" => conf})}
    else
      other -> {:error, other}
    end
  end

  def call(_stage, _env, _facts, _opts), do: {:error, :unsupported}

  defp assemble(env, kinds, aopts) do
    events =
      Enum.map(kinds, fn k ->
        %{"event_type" => k, "objects" => ["op:payment:#{env.operation_id}"], "payload" => k}
      end)

    apply(AshAffidavit, :call, [%{"op" => "assemble", "events" => events}, aopts])
  end
end
