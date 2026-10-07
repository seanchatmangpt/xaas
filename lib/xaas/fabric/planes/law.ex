defmodule Xaas.Fabric.Planes.Law do
  @moduledoc """
  `capability://law/admit` over `AshGraphLaw.law/3`. The payment cap is expressed as a SHACL
  shape over the projected graph, so an over-limit payment is refused at admission and no
  construct exists for DO. An admission is evidence of admission only; standing is derived
  elsewhere and is never ALIVE here.

  opts: `:max_amount_minor` (default 500_000), `:graphlaw` (opts passed to `AshGraphLaw.law/3`).
  """
  @behaviour Xaas.Fabric.Plane

  @impl true
  def contract,
    do: %{
      uri: "capability://law/admit",
      semantic_id: "law.admit.payment.v1",
      realization: "ash-graphlaw",
      ceiling: :construct
    }

  @impl true
  def call(:construct, _env, facts, opts) do
    cap = Keyword.get(opts, :max_amount_minor, 500_000)

    shapes = """
    @prefix sh: <http://www.w3.org/ns/shacl#> .
    @prefix ex: <https://xaas.example/fabric#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    ex:PaymentShape a sh:NodeShape ; sh:targetClass ex:Payment ;
      sh:property [ sh:path ex:amountMinor ; sh:minCount 1 ; sh:datatype xsd:integer ;
                    sh:minInclusive 1 ; sh:maxInclusive #{cap} ] .
    """

    data = %{"text" => facts["graph"], "dialect" => "turtle"}

    # apply/3: AshGraphLaw is an optional, test/dev-only dependency.
    case apply(AshGraphLaw, :law, [
           data,
           [%{"step" => "shacl", "shapes" => shapes}],
           Keyword.get(opts, :graphlaw, [])
         ]) do
      {:ok, admitted} ->
        digest =
          :crypto.hash(:sha256, :erlang.term_to_binary(admitted.nquads))
          |> Base.encode16(case: :lower)

        {:ok,
         Map.merge(facts, %{
           "law.admitted" => true,
           "law.decision" => digest,
           "law.receipts" => length(admitted.receipts)
         })}

      {:error, refusal} ->
        {:error, refusal}
    end
  end

  def call(:replay, _env, _facts, _opts), do: :ok
  def call(_stage, _env, _facts, _opts), do: {:error, :unsupported}
end
