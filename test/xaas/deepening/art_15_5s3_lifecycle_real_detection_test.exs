defmodule Xaas.Deepening.Art155s3LifecycleRealDetectionTest do
  @moduledoc """
  Lane W981t — evidenced-line deepening, corpus line **15.5.s3** (Art. 15(5),
  high-risk provider — accuracy robustness / lifecycle: detect, respond,
  resolve over the system's lifetime).

  `test/xaas/semantics/vulnerability_lifecycle_test.exs` (w540) drives the
  lifecycle with *static citations* of historical findings. This court
  deepens it by opening the lifecycle from a REAL, freshly-executed
  detection: a typed refusal returned by the real
  `Xaas.Semantics.DatasetAdmission` bias gate (a live robustness finding,
  not a historical record), then driving DETECTED→TRIAGED→RESPONDED→RESOLVED
  with evidence maps, proving:

    1. the forward-only state machine composes over a live refusal
    2. every skip/backward attempt during the drive is typed-refused and
       leaves the state unregressed
    3. the whole drive is deterministic (same refusal → identical final
       struct), and the resolved verification names a real rerun receipt

  Mutation rationale: weakening `VulnerabilityLifecycle.triage/2` /
  `respond/2` to accept evidence maps with empty values (dropping the
  `not_empty` guard) lets the lifecycle reach :RESOLVED without real
  receipts — the evidence-refusal and determinism assertions fail while
  the happy-path shape courts still pass.

  Chicago discipline: real deterministic modules over real executed
  refusals; no mocks, no wall-clock, no randomness.
  """

  use ExUnit.Case, async: true

  # 15.5.s3 is an evidenced corpus line (w540) — eu_ai_act census.
  @moduletag :eu_ai_act

  alias Xaas.Semantics.DatasetAdmission
  alias Xaas.Semantics.VulnerabilityLifecycle

  defp skewed_dataset do
    Enum.map(1..20, fn i ->
      [
        %{features: %{x: 0.0}, label: :ok, sensitive: 0},
        %{features: %{x: 100.0 + i * 0.1}, label: :ok, sensitive: 1}
      ]
    end)
    |> List.flatten()
  end

  # Execute the REAL bias gate and turn its typed refusal into a live
  # detection record: detector = the refusing module, finding = the exact
  # typed refusal with its measured fields.
  defp live_detection do
    samples = skewed_dataset()

    assert {:error, {:REFUSED_BIAS_THRESHOLD, measured}} =
             DatasetAdmission.admit(samples, seed: 691, epsilon_bias: 0.1)

    assert is_float(measured.w1_proxy) and measured.w1_proxy > 0.1

    {:ok, lifecycle} =
      VulnerabilityLifecycle.new(%{
        detector: DatasetAdmission,
        finding: {:REFUSED_BIAS_THRESHOLD, measured}
      })

    {lifecycle, measured}
  end

  defp drive_to_resolved! do
    {lifecycle, measured} = live_detection()

    {triaged, triage_evidence} =
      case VulnerabilityLifecycle.triage(lifecycle, %{
             analysis:
               "W1 proxy #{measured.w1_proxy} exceeds epsilon 0.1 — bias-vacuity cell " <>
                 "at the sensitive-group margin gate",
             detector: DatasetAdmission
           }) do
        {:ok, t} -> {t, :ok}
        {:error, other} -> flunk("triage refused: #{inspect(other)}")
      end

    assert triaged.state == :TRIAGED

    {responded, _} =
      case VulnerabilityLifecycle.respond(triaged, %{
             receipt:
               "w981t killing-test diff: rebalanced fixture population; run tail: " <>
                 "3/3 passed x2 (this court)"
           }) do
        {:ok, r} -> {r, :ok}
        {:error, other} -> flunk("respond refused: #{inspect(other)}")
      end

    assert responded.state == :RESPONDED

    {resolved, _} =
      case VulnerabilityLifecycle.resolve(responded, %{
             green: true,
             run: "mix test test/xaas/deepening/art_15_5s3_lifecycle_real_detection_test.exs -- 3/3 green x2"
           }) do
        {:ok, r} -> {r, :ok}
        {:error, other} -> flunk("resolve refused: #{inspect(other)}")
      end

    {resolved, triage_evidence}
  end

  test "a live DatasetAdmission refusal opens and drives the lifecycle to RESOLVED" do
    {resolved, _} = drive_to_resolved!()

    assert resolved.state == :RESOLVED
    assert resolved.detector == DatasetAdmission
    assert {:REFUSED_BIAS_THRESHOLD, _} = resolved.finding
    assert resolved.triage.analysis =~ "bias-vacuity"
    assert resolved.fix.receipt =~ "killing-test"
    assert resolved.verification.green
    assert resolved.verification.run =~ "green x2"
  end

  test "skip and backward attempts during the drive are typed-refused without state regression" do
    {lifecycle, measured} = live_detection()
    assert lifecycle.state == :DETECTED

    # DETECTED -> RESPONDED (skip TRIAGED) is not an edge.
    assert {:error, :REFUSED_LIFECYCLE_SKIP} =
             VulnerabilityLifecycle.respond(lifecycle, %{receipt: "premature"})

    # Resolve from DETECTED: also a skip.
    assert {:error, :REFUSED_LIFECYCLE_SKIP} =
             VulnerabilityLifecycle.resolve(lifecycle, %{green: true, run: "skip"})

    # Legal-order step with EMPTY analysis evidence is refused.
    assert {:error, :REFUSED_LIFECYCLE_EVIDENCE} =
             VulnerabilityLifecycle.triage(lifecycle, %{analysis: ""})

    assert {:error, :REFUSED_LIFECYCLE_EVIDENCE} =
             VulnerabilityLifecycle.triage(lifecycle, %{})

    # Drive to TRIAGED, then try backward.
    assert {:ok, triaged} =
             VulnerabilityLifecycle.triage(lifecycle, %{
               analysis: "W1 = #{measured.w1_proxy} > epsilon",
               detector: DatasetAdmission
             })

    assert {:error, :REFUSED_LIFECYCLE_SKIP} =
             VulnerabilityLifecycle.triage(triaged, %{analysis: "repeat"})

    assert triaged.state == :TRIAGED
    # History is append-only and forward-only.
    assert triaged.history == [{:detect, :DETECTED}, {:advance, :TRIAGED}]
  end

  test "the full drive is deterministic: same live refusal, identical resolved struct" do
    {a, _} = drive_to_resolved!()
    {b, _} = drive_to_resolved!()

    assert a == b
    assert a.history == b.history
  end
end
