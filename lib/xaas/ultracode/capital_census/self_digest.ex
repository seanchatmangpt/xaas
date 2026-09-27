defmodule Xaas.Ultracode.CapitalCensus.SelfDigest do
  @moduledoc """
  The self-digest kernel (GC-26927-SELFDIGEST): Ultracode as a work subject of
  itself — $U_t \\in Subjects(U_t)$.

  Every run produces more than a code result; it produces evidence about the
  factory. This module converts factory evidence into self-work:

  ```
  Work → Resolution → Execution → OCEL → Experience → Gap → Work_self → U_{t+1}
  ```

  The metric is the frontier ratio `R_t = frontier work / total required work`,
  with the design objective `dR/dt < 0`: repeated frontier reasoning on the
  same shape means an architecture primitive is missing, and the recurrence
  classifies which one (the G-table). This is architecture acquisition — not
  weights, not remembering prompts.

  The candidate factory is never the judge of itself: what this module emits
  is a *work order* against the currently admitted factory, promoted only
  through construct → replay → shadow → promote (Judge ≠ Candidate).
  """

  @g_table %{
    semantic: :ontology,
    structural: :marketplace_pack,
    procedural: :hddl,
    nondeterministic: :fond,
    projection: :ggen,
    routing: :sa2a,
    observation: :beam4pm_ocel,
    selection: :resolver,
    verification: :court,
    runtime: :otp_ash_reactor
  }

  @missing_kinds [:missing_capability, :missing_composition, :missing_generator, :missing_resolver_rule]

  @doc """
  The G-table: recurrence class → the primitive target that owns it
  (GC-26927-SELFDIGEST). Unknown classes are a typed refusal, never a guess —
  an unclassifiable recurrence is itself factory evidence.
  """
  @spec classify(atom()) :: {:ok, atom()} | {:refused, :unknown_class | :class_must_be_atom}
  def classify(class) when is_atom(class) do
    case Map.fetch(@g_table, class) do
      {:ok, target} -> {:ok, target}
      :error -> {:refused, :unknown_class}
    end
  end

  def classify(_), do: {:refused, :class_must_be_atom}

  @doc """
  The frontier ratio `R_t = frontier work / total required work`. A zero
  denominator is a typed refusal — no denominator fictions: no work means no
  ratio, not a perfect one.
  """
  @spec frontier_ratio(non_neg_integer(), pos_integer()) ::
          {:ok, float()} | {:refused, :empty_denominator | :invalid_counts}
  def frontier_ratio(frontier, total)
      when is_integer(total) and total > 0 and is_integer(frontier) and frontier >= 0 and frontier <= total do
    {:ok, frontier / total}
  end

  def frontier_ratio(_frontier, 0), do: {:refused, :empty_denominator}
  def frontier_ratio(_, _), do: {:refused, :invalid_counts}

  @doc "`dR/dt < 0` — the trend test for consecutive measured ratios."
  @spec improving?({:ok, float()} | {:refused, atom()}, {:ok, float()} | {:refused, atom()}) :: boolean()
  def improving?({:ok, r_prev}, {:ok, r_next}), do: r_next < r_prev
  def improving?(_, _), do: false

  @doc """
  RepeatedFrontier(x) ⇒ self-work. Given ≥2 episodes sharing one failure
  class, emit the self-ticket in the operator's format (Observed / Expected /
  Residual / Classification / Candidate repair / Falsifier / Success), with
  the four missing-kinds as open hypotheses — classification to a single
  primitive is the *falsifier's* job, decided by replaying the episodes, not
  by this function's opinion.
  """
  def self_work_order([%{failure_class: class} | _] = episodes) when length(episodes) > 1 do
    repeated? = Enum.all?(episodes, &(&1.failure_class == class))
    subjects = Enum.map(episodes, & &1[:subject])

    if repeated? do
      case classify(class) do
        {:ok, target} ->
          {:ok,
           %{
             subject: "Xaas.Ultracode.CapitalCensus.SelfDigest",
             observation: "#{length(episodes)} frontier episodes share failure class #{class}",
             expected: "existing capabilities should have composed; frontier coding was not required",
             residual: "no #{target} primitive expresses the recurring shape",
             classification: class,
             hypotheses: @missing_kinds,
             candidate_repair: {:manufacture, target},
             falsifier: {:replay, subjects},
             success: "#{max(length(episodes) - 2, 0)}/#{length(episodes)} episodes replay without frontier coding"
           }}

        refused ->
          refused
      end
    else
      {:refused, :classes_not_repeated}
    end
  end

  def self_work_order(episodes) when is_list(episodes), do: {:refused, :no_recurrence}
  def self_work_order(_), do: {:refused, :malformed_episodes}
end
