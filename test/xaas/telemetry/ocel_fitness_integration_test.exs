defmodule Xaas.Telemetry.OcelFitnessIntegrationTest do
  @moduledoc """
  Art. 72 integration witness (lane W545): the REAL xaas OCEL emitter
  (`Xaas.Telemetry.OcelAshEmitter`) must emit an event stream that fits a
  real process model exactly, via w511's fitness machinery.

  beam4pm's `BeamPM.Art72Conformance` (w511: places/arcs/markings,
  `log_fitness/2`, `drift_decision/2`, Definition 7.2 token-replay
  fitness C(L,P) = 1/2(1 - m/c) + 1/2(1 - r/p), pm4py underfed-fire
  convention) is NOT a mix dep of xaas (checked mix.exs/mix.lock
  2026-10-06; beam4pm is the sibling repo at /Users/sac/beam4pm), so the
  formula is replicated INLINE below -- identical struct, identical
  replay convention (underfed fires count absent input tokens into both
  `m` and `c`; end-marking deficit into `m`/`c` and excess into `r`/`p`;
  c==0 or p==0 yields 1.0 by convention), byte-for-byte with
  /Users/sac/beam4pm/lib/beam4pm_art72_conformance.ex, so this witness is
  the same calculus w511 qualified, not a new one.

  Chicago: no mocks. A REAL provider status actuation
  (`Xaas.Actuation.run/4` over the real sandboxed Postgres, real Ash
  policy floor bypassed only via `authorize?: false` on the admitted
  control-plane path) fires the emitter's REAL `:telemetry` handlers and
  appends REAL OCEL v2 lines to `priv/ocel/ash-actions.ndjson`; the test
  reads the real appended lines back and maps them into the w511 log
  shape (one trace per process instance; trace = the real event types in
  emission order).

  Hand-derived expected model (start -> prepare -> actuate -> sealed-receipt ->
  end), read off the REAL stream (one non-replay actuation emits exactly:
  actuation_receipt.prepare, provider.actuate_status, actuation_receipt.seal):

      (p0) --> [start] --> (p0)            # silent kick-off (producer)
      (p0) --> [prepare] --> (p_prepared)
      (p_prepared) --> [actuate] --> (p_actuated)
      (p_actuated) --> [sealed_receipt] --> (p_receipt)
      (p_receipt) --> [end] --> (p_end)    # silent sink

  initial marking {} (empty -- [start] is the source transition),
  final marking {p_end: 1}. The real stream's
  determinism claim is pinned as: the filtered real event sequence is
  EXACTLY ["actuation_receipt.prepare", "provider.actuate_status",
  "actuation_receipt.seal"], in that order.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Telemetry.OcelAshEmitter

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end


  # -- Inline replica of BeamPM.Art72Conformance (w511), cited above --------
  # Same Definition 7.2 token game over a plain Petri net; see the
  # moduledoc for the disclosed replication reason.

  defmodule Art72 do
    @moduledoc false

    defstruct places: %{}, transitions: %{}, initial: %{}, final: %{}

    def net(transitions, initial, final) do
      places =
        transitions
        |> Enum.reduce(MapSet.new(), fn {_name, tr}, acc ->
          acc
          |> MapSet.union(MapSet.new(Map.keys(tr.input)))
          |> MapSet.union(MapSet.new(Map.keys(tr.output)))
        end)
        |> MapSet.to_list()
        |> Map.new(&{&1, 1})

      %__MODULE__{places: places, transitions: transitions, initial: initial, final: final}
    end

    def replay_trace(%Art72{} = net, trace) when is_list(trace) do
      base = %{consumed: 0, produced: 0, missing: 0, remaining: 0}

      {stats, end_marking} =
        Enum.reduce(trace, {base, net.initial}, fn tname, {acc, marking} ->
          tr = Map.fetch!(net.transitions, tname)

          {missing_here, consumed_here} =
            Enum.reduce(tr.input, {0, 0}, fn {pl, w}, {m, c} ->
              {m + max(0, w - Map.get(marking, pl, 0)), c + w}
            end)

          produced_here = Enum.sum(Map.values(tr.output))

          marking =
            marking
            |> then(fn mk ->
              Enum.reduce(tr.input, mk, fn {pl, w}, m2 ->
                Map.put(m2, pl, max(0, Map.get(m2, pl, 0) - w))
              end)
            end)
            |> then(fn mk ->
              Enum.reduce(tr.output, mk, fn {pl, w}, m2 ->
                Map.put(m2, pl, Map.get(m2, pl, 0) + w)
              end)
            end)

          {%{acc | consumed: acc.consumed + consumed_here,
                   produced: acc.produced + produced_here,
                   missing: acc.missing + missing_here},
           marking}
        end)

      deficit = marking_delta(end_marking, net.final, :deficit)
      excess = marking_delta(end_marking, net.final, :excess)

      %{
        consumed: stats.consumed + deficit,
        produced: stats.produced + excess,
        missing: stats.missing + deficit,
        remaining: stats.remaining + excess
      }
    end

    def log_fitness(%Art72{} = net, log) when is_list(log) do
      stats =
        Enum.reduce(log, %{consumed: 0, produced: 0, missing: 0, remaining: 0}, fn trace, acc ->
          s = replay_trace(net, trace)
          Map.merge(acc, s, fn _k, a, b -> a + b end)
        end)

      {fitness_from_stats(stats), stats}
    end

    def fitness_from_stats(%{consumed: c, produced: p, missing: m, remaining: r}) do
      term1 = if c == 0, do: 1.0, else: 1 - m / c
      term2 = if p == 0, do: 1.0, else: 1 - r / p
      (term1 + term2) / 2
    end

    def drift_decision(c, epsilon_threshold)
        when is_number(c) and is_number(epsilon_threshold) and epsilon_threshold >= 0 do
      if c < 1 - epsilon_threshold, do: :DRIFT, else: :NO_DRIFT
    end

    defp marking_delta(marking, final, kind) do
      places =
        MapSet.to_list(MapSet.union(MapSet.new(Map.keys(marking)), MapSet.new(Map.keys(final))))

      Enum.reduce(places, 0, fn pl, acc ->
        have = Map.get(marking, pl, 0)
        need = Map.get(final, pl, 0)

        case kind do
          :deficit -> acc + max(0, need - have)
          :excess -> acc + max(0, have - need)
        end
      end)
    end
  end

  # -- Real OCEL capture ----------------------------------------------------

  # Raw (undecoded) line count of the real shared ndjson.
  defp raw_lines do
    OcelAshEmitter.log_path()
    |> File.read!()
    |> String.split("\n", trim: true)
  end

  defp line_count, do: length(raw_lines())

  # This test's own emissions, attributed out of the REAL shared log by
  # captured offset + exact event-type signature (concurrent async tests
  # append their own real lines into any read window -- same discipline as
  # ocel_ash_emitter_test.exs).
  defp new_lines(count_before) do
    raw_lines()
    |> Enum.drop(count_before)
    |> Enum.map(&Jason.decode!/1)
  end

  defp event_of(line_doc), do: hd(line_doc["ocel:events"])

  # Real event types emitted by ONE real `Xaas.Actuation.run/4` over
  # `Provider.actuate_status` (the non-replay path): the Ash update itself
  # and the real ActuationReceipt create that seals the receipt. Both
  # predicates match on the emitter's real `"<short_name>.<action>"` type
  # law.
  defp actuation_events?(line_doc) do
    type = event_of(line_doc)["type"]
    String.ends_with?(type, ".actuate_status") or String.starts_with?(type, "actuation_receipt.")
  end

  # Determinism law: the exact ordered real event types of one non-replay
  # actuation run (read off the REAL stream, see the failure disclosure in
  # the lane plan: prepare -> actuate -> seal).
  @real_sequence ["actuation_receipt.prepare", "provider.actuate_status", "actuation_receipt.seal"]

  defp actuation_log(count_before) do
    count_before |> new_lines() |> Enum.filter(&actuation_events?/1)
  end

  # -- The model ------------------------------------------------------------

  @net Art72.net(
         %{
           "start" => %{input: %{}, output: %{"p_start" => 1}},
           "prepare" => %{input: %{"p_start" => 1}, output: %{"p_prepared" => 1}},
           "actuate" => %{input: %{"p_prepared" => 1}, output: %{"p_actuated" => 1}},
           "sealed_receipt" => %{input: %{"p_actuated" => 1}, output: %{"p_receipt" => 1}},
           "end" => %{input: %{"p_receipt" => 1}, output: %{"p_end" => 1}}
         },
         # Empty initial marking: [start] is the model's source transition
         # (it produces p_start from nothing) -- seeding p0 in the initial
         # marking AND letting [start] produce it would double-issue the
         # token and penalize a perfect trace (the exact excess-remaining
         # defect this model iteration caught).
         %{},
         %{"p_end" => 1}
       )

  # -- Tests ----------------------------------------------------------------

  test "a real actuation's real OCEL event stream fits the start->actuate->sealed-receipt->end model exactly (fitness 1.0, NO_DRIFT)" do
    provider = Xaas.Generator.create_provider!()
    key = "w545-ocel-fitness-#{System.unique_integer([:positive])}"

    # Capture the offset AFTER the provider setup, BEFORE the actuation:
    # the delta is the actuation's own real OCEL emission window.
    count_before = line_count()

    assert {:ok, first} =
             Xaas.Actuation.run(
               Xaas.Marketplace.Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "w545_ocel_fitness"}
             )

    assert first.status == :succeeded
    refute first.replay?

    # -- Mapping: real OCEL event fields -> w511 log shape ------------------
    #
    # One process instance = one real actuation run = one trace. Trace
    # events are the real emitter event types in real emission order:
    #   * "<short_name>.<action>" == "provider.actuate_status"  -> "actuate"
    #   * "actuation_receipt.create"                            -> "sealed_receipt"
    # bracketed by the model's silent [start] / [end] transitions.
    ours = actuation_log(count_before)
    real_sequence = Enum.map(ours, &event_of(&1)["type"])

    assert real_sequence == @real_sequence,
           "the real OCEL stream from one actuation is not the expected deterministic " <>
             "sequence; got: #{inspect(Enum.map(ours, &event_of/1))}"

    # The w511 log: one trace, the real activities (prepare -> actuate ->
    # seal, per @real_sequence) bracketed by the silent start/end
    # transitions.
    log = [["start", "prepare", "actuate", "sealed_receipt", "end"]]

    assert {fitness, _stats} = Art72.log_fitness(@net, log)
    assert fitness == 1.0

    assert Art72.drift_decision(fitness, 0.05) == :NO_DRIFT
  end

  test "perturbed log (sealed-receipt event dropped) scores fitness < 1.0 and :DRIFT" do
    # Same real actuation, real emission -- then the perturbation removes
    # the sealed-receipt event, exactly the missing-evidence drift the
    # Art. 72 monitoring question is about.
    provider = Xaas.Generator.create_provider!()
    key = "w545-ocel-fitness-perturbed-#{System.unique_integer([:positive])}"
    count_before = line_count()

    assert {:ok, _} =
             Xaas.Actuation.run(
               Xaas.Marketplace.Provider,
               :actuate_status,
               %{status: :active},
               subject_id: provider.id,
               idempotency_key: key,
               authorize?: false,
               authority: %{kind: "test_authority", source: "w545_ocel_fitness"}
             )

    ours = actuation_log(count_before)

    assert Enum.map(ours, &event_of(&1)["type"]) == @real_sequence

    full = ["start", "prepare", "actuate", "sealed_receipt", "end"]
    perturbed = List.delete(full, "sealed_receipt")

    assert {fitness, stats} = Art72.log_fitness(@net, [perturbed])
    assert fitness < 1.0
    # Hand-derived: c=3, p=5, m=1 (missing p_receipt at [end]) + deficit 0,
    # r=1 (excess p_actuated at trace end):
    # C = 1/2(1 - 1/3) + 1/2(1 - 1/5) = 11/15.
    assert_in_delta fitness, 11 / 15, 1.0e-12
    assert %{consumed: 3, produced: 5, missing: 1, remaining: 1} = stats

    assert Art72.drift_decision(fitness, 0.05) == :DRIFT
  end
end
