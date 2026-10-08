defmodule Xaas.EUAIAct.Art14xOversightDeepeningTest do
  @moduledoc """
  Lane W984ey — corpus evidenced-line deepening, Art. 14.x (human oversight).

  Statute (Regulation (EU) 2024/1689), Art. 14:

    * 14.1/14.3/14.3.a — oversight measures are BUILT IN to the system so a
      natural person can halt it to a safe state; the measures must be
      effective in operation, not prose.
    * 14.2 — oversight measures prevent/minimise risk; minimisation must
      bind at the measured boundary.
    * 14.3.b — deployer-implementable oversight procedures must exist as
      usable structured operator material, not prose promises.
    * 14.4.a — the overseer can understand/monitor: the stop receipt is
      durable and inspectable.

  Prior coverage: `title_iii_test.exs` deepening kinds bind 14.1–14.3.b to
  `[:quiescent_typed]` inside the generated per-line test bodies; the
  dedicated deepening files (W981t … W984ec) did NOT take any 14.x line.
  14.4.b (briefing), 14.4.c (counterfactual/shapley), 14.4.d/e (override +
  stop) are already courtered by
  `test/xaas/semantics/automation_bias_countermeasure_test.exs`,
  `test/xaas/semantics/counterfactual_test.exs`,
  `test/xaas/actuation/quiescent_stop_test.exs` — not duplicated here.
  This lane courts 14.1, 14.2, 14.3, 14.3.a, 14.3.b, plus a dedicated
  14.4.a monitoring leg, on the repo's REAL oversight seams:
  `Xaas.Actuation.QuiescentStop`, `Xaas.Semantics.RobustMargin`,
  `Xaas.Semantics.Counterfactual`, `Xaas.Semantics.OversightGovernance`.

  Chicago discipline: real Ash resources over sandboxed Postgres, real gate
  executions; assertions on final returned state only; zero mocks.
  Zero-config: thresholds are call arguments, no application env.
  """

  use ExUnit.Case, async: true

  alias Xaas.Actuation.QuiescentStop
  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.ActuationIntent
  alias Xaas.Operations.ActuationReceipt
  alias Xaas.Semantics.{Counterfactual, OversightGovernance, RobustMargin}

  require Ash.Query

  @moduletag :eu_ai_act

  # -- fixtures --------------------------------------------------------------

  defp create_provider!(tag) do
    Xaas.Generator.create_provider!(%{
      name: "Art14 #{tag} #{System.unique_integer([:positive])}",
      org_id: "org-art14x"
    })
  end

  defp authority do
    %{kind: "human_oversight", source: "art14x_oversight_deepening_test"}
  end

  defp stop_key(tag), do: "art14x-#{tag}-#{System.unique_integer([:positive])}"

  defp claim_key(resource, subject_id),
    do: "quiescent-stop:" <> inspect(resource) <> ":" <> to_string(subject_id)

  # -- Court 1 — 14.1 / 14.3 / 14.3.a: the built-in stop measure is EFFECTIVE --

  @tag :art14x_court1
  test "14.1/14.3/14.3.a: built-in stop measure drives a real subject quiescent under a named human authority, refuses fail-closed without one, and the attractor is monotone" do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    stopper = create_provider!(:court1_stopper)
    unassigned = create_provider!(:court1_unassigned)
    authority_map = authority()

    # Built-in + effective: the stop DO lands on a real subject.
    assert {:ok, receipt} =
             QuiescentStop.execute(Provider,
               subject_id: stopper.id,
               idempotency_key: stop_key(:court1),
               authority: authority_map
             )

    assert receipt.target == :quiescent
    assert %DateTime{} = receipt.stopped_at
    assert receipt.authority == authority_map
    assert Provider |> Ash.get!(stopper.id, authorize?: false) |> Map.fetch!(:status) == :suspended

    # The oversight act is durable: the intent-ledger claim row carries the
    # authority that performed it.
    assert {:ok, claim} =
             Ash.read_one(
               Ash.Query.filter(ActuationIntent,
                 idempotency_key == ^claim_key(Provider, stopper.id)
               ),
               authorize?: false
             )

    assert claim.status == :admitted

    # The ledger serialises the authority map (string-keyed storage); the
    # assigned human authority identity must round-trip intact.
    assert claim.authority == %{
             "kind" => authority_map.kind,
             "source" => authority_map.source
           }

    # Fail-closed: no authority, no DO, no durable assignment.
    assert {:error, :REFUSED_STOP_AUTHORITY} =
             QuiescentStop.execute(Provider,
               subject_id: unassigned.id,
               idempotency_key: stop_key(:court1_unassigned),
               authority: %{}
             )

    assert Provider
           |> Ash.get!(unassigned.id, authorize?: false)
           |> Map.fetch!(:status) != :suspended

    assert {:ok, nil} =
             Ash.read_one(
               Ash.Query.filter(ActuationIntent,
                 idempotency_key == ^claim_key(Provider, unassigned.id)
               ),
               authorize?: false
             )

    # Monotone attractor: a fresh-key stop on the stopped subject refuses
    # typed; the safe state is kept, not re-entered.
    assert {:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT} =
             QuiescentStop.execute(Provider,
               subject_id: stopper.id,
               idempotency_key: stop_key(:court1_fresh),
               authority: authority_map
             )

    assert Provider |> Ash.get!(stopper.id, authorize?: false) |> Map.fetch!(:status) ==
             :suspended
  end

  # -- Court 2 — 14.2: oversight risk minimisation binds at the boundary ------

  @tag :art14x_court2
  test "14.2: the margin gate minimises risk fail-closed at the exact measured boundary and the typed refusal is counterfactually attributable" do
    # Real margin gate, real boundary: penalty = l_h * l_e * eps. Admit at
    # margin == penalty (downward-closed region, inclusive boundary), refuse
    # one notch below — risk exposure is bounded exactly where the gate says.
    l_h = 2.0
    l_e = 3.0
    eps = 0.5
    penalty = l_h * l_e * eps

    assert RobustMargin.admit(penalty, l_h, l_e, eps) == :ADMITTED
    assert RobustMargin.admit(penalty * 0.999, l_h, l_e, eps) == {:error, :REFUSED_ROBUST_MARGIN}

    # The typed refusal is a real recourse variable: record the refusal as a
    # W506 decision record whose oversight check list includes the margin
    # gate itself, then counterfactually repair the margin and watch the
    # decision flip with the causal delta naming the margin check.
    margin_check = fn input ->
      if RobustMargin.admit(input.margin, l_h, l_e, eps) == :ADMITTED,
        do: :ok,
        else: {:refused, :REFUSED_ROBUST_MARGIN}
    end

    human_oversight_check = fn input ->
      if is_binary(get_in(input, [:authority, :source])) and
           get_in(input, [:authority, :source]) != "",
        do: :ok,
        else: {:refused, :REFUSED_STOP_AUTHORITY}
    end

    checks = [
      human_oversight: human_oversight_check,
      robust_margin: margin_check
    ]

    refused_input = %{margin: penalty * 0.9, authority: authority()}
    %{outcome: outcome, checks: log} = Counterfactual.run(refused_input, checks)

    assert outcome == {:refused, :REFUSED_ROBUST_MARGIN}
    assert [%{name: :human_oversight, verdict: :pass, refusal: nil}] = Enum.take(log, 1)

    record = %{
      input: refused_input,
      admitted?: false,
      refusal: :REFUSED_ROBUST_MARGIN,
      checks: log
    }

    repaired = %{margin: penalty, authority: authority()}

    assert {:ok, cf} = Counterfactual.evaluate(record, repaired, checks)
    assert cf.outcome == :admitted
    assert cf.changed?
    assert cf.explanation =~ "robust_margin"
  end

  # -- Court 3 — 14.3.b + 14.4.a: operator material + durable monitoring ------

  @tag :art14x_court3
  test "14.3.b/14.4.a: deployer-implementable oversight material exists as structured data with on-disk evidence, and a real stop is durably monitored via a sealed receipt row" do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    # 14.3.b: the oversight procedures are STRUCTURED DATA whose citations are
    # real, existing files — usable operator material, not prose promises.
    assert {:ok, oversight} = OversightGovernance.fria_oversight_description()

    assert is_list(oversight.description) and length(oversight.description) > 0
    assert Enum.all?(oversight.controls, &is_binary/1)

    assert {:ok, literacy} = OversightGovernance.ai_literacy()
    assert length(literacy.measures) > 0
    assert literacy.audience =~ "oversight"

    cited =
      OversightGovernance.cited_paths()

    assert length(cited) > 0

    every_cited_path =
      (oversight.controls ++ Enum.flat_map(literacy.measures, & [&1.evidence_path]) ++ cited)
      |> Enum.uniq()

    missing =
      Enum.filter(every_cited_path, fn path ->
        not File.exists?(Path.expand(path, File.cwd!()))
      end)

    assert missing == [],
           "oversight material cites non-existent paths: #{inspect(missing)}"

    # 14.4.a: the overseer can MONITOR — the stop DO is durable as a sealed
    # receipt row over a real subject, inspectable after the fact.
    provider = create_provider!(:court3)

    assert {:ok, _receipt} =
             QuiescentStop.execute(Provider,
               subject_id: provider.id,
               idempotency_key: stop_key(:court3),
               authority: authority()
             )

    assert {:ok, receipt_row} =
             Ash.read_one(
               Ash.Query.filter(ActuationReceipt,
                 resource_module == ^inspect(Provider) and subject_id == ^to_string(provider.id)
               ),
               authorize?: false
             )

    assert receipt_row.action == "actuate_status"
    assert receipt_row.status == :succeeded
  end
end
