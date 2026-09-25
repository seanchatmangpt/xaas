defmodule Xaas.Ultracode.CourtReceipt do
  @moduledoc """
  The fabric court-receipt producer for non-APS target suites: turns a
  generic suite's per-test output into `acceptance_results` /
  `falsifier_results` / `court_results` KEYED BY the work order's minted
  IRIs, plus a court<->fabric-step binding.

  ## The consumer contract this module implements (ggen side,
     `GgenIgniter.SemanticJira.promote/3`, branch
     feat/semantic-jira-v26.9.19)

  `promote/3`'s promotion checks read, from the EVIDENCE map it is handed
  (the sealed fabric receipt's evidence, passed through by the crown
  driver):

    * `courts` check -- for every `admitted["required_courts"]` IRI:
      `get_in(evidence, ["court_results", court_iri, "passed"]) == true`
      (semantic_jira.ex courts_satisfied?/2);
    * `acceptance` check -- for every `admitted["acceptance"]` IRI:
      `get_in(evidence, ["acceptance_results", iri]) == true`
      (acceptance_satisfied?/2);
    * `falsifiers` check -- for every `admitted["falsifiers"]` IRI:
      `get_in(evidence, ["falsifier_results", iri]) in ["survived", true]`
      (falsifiers_satisfied?/2).

  The minted IRIs are the work order's `sj:acceptance` / `sj:falsifier` /
  `sj:requiresCourt` objects, e.g. CROWN2-001's
  `https://ggen-igniter.dev/ontology/semantic-jira#obs-275a1f5e4de7-acceptance-delta`
  and
  `https://ggen-igniter.dev/ontology/semantic-jira#exact-head-projection-court`.
  Without these keys a genuine alive+verified close is still refused with
  `{:error, {:promotion_refused, [:courts, :evidence, :acceptance,
  :falsifiers]}}` -- this module is what lets the fabric WITNESS those
  verdicts instead of the worker asserting them.

  ## Verdict vocabulary (mirrors the consumer exactly)

    * acceptance IRI -> `true` when its mapped test PASSED, `false` when it
      did not;
    * falsifier IRI -> `"survived"` when its mapped test PASSED (the
      falsification attempt failed to reproduce the delta -- the repair
      holds), `"failed"` when it did not (the delta reproduces: the repair
      is falsified).

  ## The court map (which IRI means which check)

  The mapping is UPSTREAM data, minted with the work order, carried on the
  execution descriptor (`Xaas.Ultracode.SemanticWork`'s optional
  `court_map` field) and persisted on the Run -- it is fabric-owned state,
  never per-call worker input. Shape:

      %{
        "acceptance" => %{iri => %{"test" => test_id}},
        "falsifiers" => %{iri => %{"test" => test_id}},
        "courts"     => [court_iri]
      }

  A predicate is v1-exactly `%{"test" => test_id}`: the id of the one test
  whose outcome decides the verdict, in the suite's native id syntax (for
  `pytest -v`: `tests/test_w7_crown_seed.py::test_name`; for
  `mix test --trace`: the test description; for `exit_status`: the receipt
  step's own id). Unknown predicate kinds are REFUSED, never silently
  ignored -- a mapping the fabric does not understand must not quietly
  become "no court".

  ## The `exit_status` result format

  For a suite whose receipt step IS the check (e.g. `mix format
  --check-formatted`), the verdict is the step's observed exit status, not
  parsed output: `%{step_id => :pass}` when the step exited 0,
  `%{step_id => :fail}` when it exited non-zero and was judged `"fail"`.
  A step with no observed exit (timeout, spawn error) or an infra exit
  (status `"error"`) yields NO verdict, so a mapped IRI is refused with
  `:missing_verdict` -- an unobserved exit is never a defaulted pass or fail.

  ## Fail-closed law

  Every declared IRI must get an OBSERVED verdict from the suite output. A
  mapped test id with no verdict line is `{:error, {:missing_verdict, _}}`
  -- never a defaulted verdict, never a skipped row. The caller
  (`Xaas.Ultracode.Verifier`) turns any production refusal into a typed
  `"error"` result (`{:court_receipt_refused, reason}`), which
  `Lease.close/4` seals as `:partial_alive`: the work may be fine, but the
  court could not witness it, and `:alive` requires a qualifying court.
  """

  @result_formats ~w(pytest_v mix_trace exit_status)

  @type predicate :: %{required(String.t()) => String.t()}

  @type court_map :: %{
          optional(String.t()) => %{String.t() => predicate()},
          optional(String.t()) => [String.t()]
        }

  @doc "Supported suite output profiles (suite-level `result_format`)."
  @spec result_formats() :: [String.t()]
  def result_formats, do: @result_formats

  @doc """
  Admits a court map as carried on the descriptor/Run. `{:ok, nil}` for an
  absent map (no court receipt contract); `{:ok, court_map}` for a valid
  one; a typed refusal otherwise.
  """
  @spec admit(term()) :: {:ok, court_map() | nil} | {:error, term()}
  def admit(nil), do: {:ok, nil}

  def admit(map) when is_map(map) do
    with :ok <- refuse_unknown_keys(map, ~w(acceptance falsifiers courts)),
         :ok <- require_any_entry(map),
         {:ok, _acceptance} <- admit_group(map, "acceptance"),
         {:ok, _falsifiers} <- admit_group(map, "falsifiers"),
         :ok <- admit_courts(map["courts"]) do
      {:ok, Map.take(map, ~w(acceptance falsifiers courts))}
    end
  end

  def admit(_other), do: {:error, {:refused_court_map, :not_a_map}}

  @doc """
  Produces the IRI-keyed court receipt from one receipt step's output.

  `suite_name` names the registered suite; `suite` is its declaration map
  (`result_format` picks the output profile); `step_result` is the
  verifier's string-keyed step map (`"id"`, `"status"`, `"output_tail"`);
  `head` and `argv_sha256` bind the receipt to the exact judged head +
  command. Production does NOT require the step to have passed -- a RED
  run's output still witnesses per-IRI verdicts (acceptance `false`,
  falsifier `"failed"`), which is exactly what the falsifier path must
  record. Returns `{:ok, receipt}` or `{:error, reason}` -- never a
  partial receipt, never an invented verdict.
  """
  @spec produce(court_map(), String.t(), map(), map(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def produce(court_map, suite_name, suite, step_result, head, argv_sha256)
      when is_binary(suite_name) do
    format = Map.get(suite, :result_format)

    with {:ok, ^format} <- check_format(format),
         {:ok, verdicts} <- verdicts(format, step_result) do
      binding = %{
        "suite" => suite_name,
        "step_id" => step_result["id"],
        "head" => head,
        "argv_sha256" => argv_sha256
      }

      acceptance = Map.get(court_map, "acceptance", %{})
      falsifiers = Map.get(court_map, "falsifiers", %{})
      courts = Map.get(court_map, "courts", [])

      with {:ok, acceptance_results} <- keyed_verdicts(acceptance, verdicts, :acceptance),
           {:ok, falsifier_results} <- keyed_verdicts(falsifiers, verdicts, :falsifiers) do
        {:ok,
         %{
           "binding" => binding,
           "acceptance_results" => acceptance_results,
           "falsifier_results" => falsifier_results,
           "court_results" => court_results(courts, binding, step_result["status"] == "pass")
         }}
      end
    end
  end

  @doc """
  The step's verbose argv when a court receipt contract is in force
  (`receipt_argv`, so a generic suite can opt into per-test output without
  changing its plain run), else the plain argv.
  """
  @spec step_argv(map(), boolean()) :: [String.t()]
  def step_argv(_step, false), do: nil

  def step_argv(step, true) do
    case Map.get(step, :receipt_argv) do
      argv when is_list(argv) and argv != [] -> argv
      _ -> Map.get(step, :argv)
    end
  end

  # ------------------------------------------------------------------
  # Admission
  # ------------------------------------------------------------------

  defp refuse_unknown_keys(map, allowed) do
    unknown = Map.keys(map) -- allowed

    if unknown == [] do
      :ok
    else
      {:error, {:refused_court_map, {:unknown_keys, unknown}}}
    end
  end

  defp require_any_entry(map) do
    if map["acceptance"] in [nil, %{}] and map["falsifiers"] in [nil, %{}] and
         map["courts"] in [nil, []] do
      {:error, {:refused_court_map, :empty}}
    else
      :ok
    end
  end

  defp admit_group(map, group) do
    case Map.get(map, group) do
      nil ->
        {:ok, %{}}

      predicates when is_map(predicates) ->
        Enum.reduce_while(predicates, {:ok, %{}}, fn {iri, predicate}, {:ok, acc} ->
          with :ok <- admit_iri(iri, group),
               {:ok, test_id} <- admit_predicate(predicate) do
            {:cont, {:ok, Map.put(acc, iri, %{"test" => test_id})}}
          else
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)

      _other ->
        {:error, {:refused_court_map, {:invalid_group, group}}}
    end
  end

  defp admit_iri(iri, group) when is_binary(iri) and iri != "" do
    if String.contains?(iri, ":"),
      do: :ok,
      else: {:error, {:refused_court_map, {:invalid_iri, group, iri}}}
  end

  defp admit_iri(iri, group), do: {:error, {:refused_court_map, {:invalid_iri, group, iri}}}

  # v1: exactly one supported predicate kind. An unknown kind inside an
  # otherwise-shaped predicate is a refusal, not an ignore.
  defp admit_predicate(%{} = predicate) do
    case Map.to_list(predicate) do
      [{"test", test_id}] when is_binary(test_id) and test_id != "" ->
        {:ok, test_id}

      [{"test", _}] ->
        {:error, {:refused_court_map, {:invalid_predicate, predicate}}}

      _other_keys ->
        {:error, {:refused_court_map, {:unknown_predicate, predicate}}}
    end
  end

  defp admit_predicate(other), do: {:error, {:refused_court_map, {:invalid_predicate, other}}}

  defp admit_courts(nil), do: :ok

  defp admit_courts(courts) when is_list(courts) do
    Enum.reduce_while(courts, :ok, fn iri, :ok ->
      case admit_iri(iri, "courts") do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp admit_courts(other), do: {:error, {:refused_court_map, {:invalid_courts, other}}}

  # ------------------------------------------------------------------
  # Production
  # ------------------------------------------------------------------

  defp check_format(format) when format in @result_formats, do: {:ok, format}
  defp check_format(nil), do: {:error, {:refused_court_receipt, :result_format_undeclared}}

  defp check_format(other),
    do: {:error, {:refused_court_receipt, {:unknown_result_format, other}}}

  # Per-test verdicts observed in the step: %{test_id => :pass | :fail}.
  # `exit_status` judges the step itself by its observed exit code; the
  # output profiles parse the step's captured output tail.
  defp verdicts("exit_status", step_result), do: {:ok, exit_verdict(step_result)}

  defp verdicts(format, step_result) when format in ["pytest_v", "mix_trace"],
    do: output_verdicts(format, step_result["output_tail"] || "")

  defp verdicts(_, _), do: {:error, {:refused_court_receipt, :result_format_undeclared}}

  defp exit_verdict(%{"id" => id, "exit" => 0, "status" => "pass"}) when is_binary(id),
    do: %{id => :pass}

  defp exit_verdict(%{"id" => id, "exit" => code, "status" => "fail"})
       when is_binary(id) and is_integer(code) and code != 0,
       do: %{id => :fail}

  defp exit_verdict(_unobserved), do: %{}

  defp output_verdicts("pytest_v", output) do
    line_regex = ~r/^(?<id>\S+::\S+)\s+(?<verdict>PASSED|FAILED|ERROR|XFAIL|XPASS|SKIPPED)\b/

    verdicts =
      output
      |> String.split("\n")
      |> Enum.reduce(%{}, fn line, acc ->
        case Regex.named_captures(line_regex, line) do
          %{"id" => id, "verdict" => "PASSED"} -> Map.put(acc, id, :pass)
          %{"id" => id, "verdict" => _} -> Map.put(acc, id, :fail)
          nil -> acc
        end
      end)

    {:ok, verdicts}
  end

  # `mix test --trace`: each finished test prints `  * description (time)`;
  # failing tests are re-listed in the Failures section as `  N) description
  # (file.ex:line)`. A description fails iff it appears in the failure
  # re-listing; the run line alone is not evidence of passing.
  defp output_verdicts("mix_trace", output) do
    lines = String.split(output, "\n")

    run_lines =
      Enum.flat_map(lines, fn line ->
        case Regex.run(~r/^\s+\*\s+(.+?)\s+\([\d.]+m?s\)\s*$/, line) do
          [_, desc] -> [desc]
          _ -> []
        end
      end)

    failed =
      MapSet.new(
        Enum.flat_map(lines, fn line ->
          # `\s*` (not `\s+`): ExUnit indents failure entries, but a heredoc-
          # trimmed or differently-indented runner must not hide a failure
          # from the court -- missing a failure would mint a false "survived".
          case Regex.run(~r/^\s*\d+\)\s+(.+?)\s+\([^)]+\)\s*$/, line) do
            [_, desc] -> [desc]
            _ -> []
          end
        end)
      )

    verdicts =
      run_lines
      |> Map.new(fn desc -> {desc, if(MapSet.member?(failed, desc), do: :fail, else: :pass)} end)
      |> Map.merge(Map.new(MapSet.to_list(failed), fn desc -> {desc, :fail} end))

    {:ok, verdicts}
  end

  # One observed verdict per declared IRI, mapped into the consumer's
  # vocabulary. A mapped test with NO observed verdict is a refusal -- a
  # defaulted or skipped row would be a fabricated verdict.
  defp keyed_verdicts(predicates, verdicts, group) when is_map(predicates) do
    Enum.reduce_while(predicates, {:ok, %{}}, fn {iri, predicate}, {:ok, acc} ->
      test_id = predicate["test"]

      case Map.fetch(verdicts, test_id) do
        {:ok, :pass} ->
          verdict = if group == :acceptance, do: true, else: "survived"
          {:cont, {:ok, Map.put(acc, iri, verdict)}}

        {:ok, :fail} ->
          verdict = if group == :acceptance, do: false, else: "failed"
          {:cont, {:ok, Map.put(acc, iri, verdict)}}

        :error ->
          {:halt, {:error, {:refused_court_receipt, {:missing_verdict, group, iri, test_id}}}}
      end
    end)
  end

  defp keyed_verdicts(_other, _verdicts, group),
    do: {:error, {:refused_court_receipt, {:invalid_group, group}}}

  # The court<->fabric-step binding: every declared court IRI records the
  # passing receipt step that judged it (suite, step id, exact head,
  # command digest). An omitted "courts" list yields %{} -- the consumer's
  # courts check then refuses rather than passing on an undeclared court.
  defp court_results(courts, _binding, _passed) when courts in [nil, []], do: %{}

  defp court_results(courts, binding, passed) when is_list(courts) do
    Map.new(courts, fn iri ->
      {iri,
       %{
         "passed" => passed == true,
         "suite" => binding["suite"],
         "step_id" => binding["step_id"],
         "head" => binding["head"],
         "argv_sha256" => binding["argv_sha256"]
       }}
    end)
  end
end
