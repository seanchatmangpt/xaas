defmodule Xaas.Ultracode.WaveLoop.State do
  @moduledoc """
  Tolerant parser and renderer for the wave loop's STATE file
  (`/Users/sac/xaas/tmp/w8-loop/STATE.md` -- lives under the repo root's
  gitignored `tmp/`, like all loop telemetry; see the file's own header and
  `Xaas.Ultracode.WaveLoop`).

  The parser is deliberately narrow: it understands exactly the shapes the
  loop's own writers (coordinator updates, step workers, this loop) produce,
  and anything else is a TYPED refusal -- never a crash, never a guess
  (the loop's "corrupted STATE -> typed refusal + telemetry" law).

  ## Grammar (each rule tested)

    * STEP TABLE -- the LAST markdown table whose header row is
      `| step | status | evidence |` (case/space tolerant; a later
      coordinator update supersedes earlier tables). Data rows are
      `| <id> <name> | <status> | <evidence> |` with an integer id; the
      coordinator's omitted-empty-evidence form `| <id> <name> | <status>
      |` (two cells, live STATE row 4 on 2026-09-21) parses as
      empty-evidence. The `|---|` separator row is skipped. Escaped cells
      (`\\|`) round-trip.
    * STATUS -- one of (case-insensitive):

        * starts with `done` or contains the whole word `complete` -> `:done`
        * contains `pending` -> `:pending`
        * contains `blocked` -> `:blocked` (a `READY-` prefix is fine)
        * anything else -> `{:error, {:malformed_state, {:unknown_status, ...}}}`

    * ROW DEPS -- a `BLOCKED-ON-<ids>` token in the status cell (ids joined
      by `+`/`,`/spaces) contributes dependencies.
    * REMAINING NOTE -- the LAST line starting with `REMAINING`:

        `REMAINING after <d1+d2,...>: step <a> <desc>, then step <b> <desc>...`

      The `after <deps>` clause binds to the FIRST listed step; every later
      listed step depends on its predecessor in the list (the chain). Steps
      named in the note REMAIN actionable even when their table row already
      says `DONE` (the note is how a coordinator re-opens work, e.g. the
      step-8 re-sweep). Listed steps and after-deps must exist in the step
      table, else a typed refusal.
    * COMPLETION -- an explicit `LOOP COMPLETE` marker line, or no
      actionable step left (every table step `:done` and the note lists
      nothing). The loop trusts a STATE-authored terminal claim because the
      evidence law puts the post-merge CI check inside the step worker's
      acceptance, never in the loop.
    * SECTIONS -- `### [<id>] <title>` blocks (verbatim step dispatch
      instructions), plus the `## (a)` standing and `## (c)` law sections,
      all optional; only the step table is mandatory.

  ## Rendering

  `set_row/4`, `remove_from_remaining/2` and `append_complete_marker/2`
  rewrite the minimum number of lines and are what the loop's atomic
  (temp + rename) STATE write persists: a row's status/evidence cells, one
  step removed from the note, one completion marker. Everything else in the
  file is preserved.
  """

  @enforce_keys [:steps, :sections, :remaining_chain]
  defstruct [
    :steps,
    :sections,
    :standing,
    :law,
    :remaining_note,
    :remaining_chain,
    :complete_marker
  ]

  @type step :: %{
          required(:id) => String.t(),
          required(:name) => String.t(),
          required(:status) => :done | :pending | :blocked | :unknown,
          required(:status_raw) => String.t(),
          required(:evidence) => String.t(),
          required(:deps) => [String.t()]
        }

  @type t :: %__MODULE__{
          steps: [step()],
          sections: %{optional(String.t()) => String.t()},
          standing: String.t() | nil,
          law: String.t() | nil,
          remaining_note: String.t() | nil,
          remaining_chain: %{optional(String.t()) => [String.t()]},
          complete_marker: boolean()
        }

  @step_header_regex ~r/^\s*\|\s*step\s*\|\s*status\s*\|\s*evidence/i
  @complete_marker_regex ~r/\bLOOP COMPLETE\b/
  @listed_step_regex ~r/\bstep\s+(\d+)/i

  # ------------------------------------------------------------------
  # Parsing
  # ------------------------------------------------------------------

  @spec parse(binary()) :: {:ok, t()} | {:error, {:malformed_state, term()}}
  def parse(raw) when is_binary(raw) do
    lines = String.split(raw, ["\r\n", "\n"])
    note = remaining_note(lines)

    with {:ok, rows} <- step_table(lines),
         {:ok, steps0} <- rows_to_steps(rows),
         table_ids = MapSet.new(steps0, & &1.id),
         {:ok, chain} <- parse_remaining(note, table_ids) do
      sections = extract_sections(lines)

      {:ok,
       %__MODULE__{
         steps: Enum.map(steps0, &%{&1 | deps: Enum.uniq(&1.deps ++ Map.get(chain, &1.id, []))}),
         sections: sections.step_sections,
         standing: sections.standing,
         law: sections.law,
         remaining_note: note,
         remaining_chain: chain,
         complete_marker: Enum.any?(lines, &(&1 =~ @complete_marker_regex))
       }}
    end
  end

  def parse(_other), do: {:error, {:malformed_state, :not_a_string}}

  # The FIRST step (table order) that still owes work AND whose deps are all
  # done. A step owes work when its status is :pending/:blocked OR the
  # REMAINING note names it (the note re-opens a DONE row, e.g. a re-sweep).
  # A dep counts as done only when its row is :done and the note does not
  # re-open it.
  @spec first_actionable(t()) :: {:ok, step()} | {:waiting, step(), [String.t()]} | :complete
  def first_actionable(%__MODULE__{steps: steps, remaining_chain: chain}) do
    note_listed = MapSet.new(Map.keys(chain))

    done_ids =
      steps
      |> Enum.filter(fn s -> s.status == :done and not MapSet.member?(note_listed, s.id) end)
      |> MapSet.new(& &1.id)

    case Enum.find(steps, fn s ->
           s.status in [:pending, :blocked] or MapSet.member?(note_listed, s.id)
         end) do
      nil ->
        :complete

      %{} = next ->
        case Enum.reject(next.deps, &MapSet.member?(done_ids, &1)) do
          [] -> {:ok, next}
          unmet -> {:waiting, next, unmet}
        end
    end
  end

  @spec complete?(t()) :: boolean()
  def complete?(%__MODULE__{complete_marker: true}), do: true

  def complete?(%__MODULE__{} = state) do
    first_actionable(state) == :complete
  end

  # ------------------------------------------------------------------
  # Rendering (minimum-line rewrites; the caller persists atomically)
  # ------------------------------------------------------------------

  @doc """
  Rewrites step `id`'s row in the LAST step table. `new_status` (a binary)
  replaces the status cell when the row's current status is not already
  `:done` -- a worker's own DONE wording is never clobbered; pass `nil` to
  leave the status untouched. `evidence_append` (a binary) is appended to
  the evidence cell unless the cell already contains it (idempotent
  re-ticks); pass `nil` to leave evidence untouched.
  """
  @spec set_row(binary(), String.t(), String.t() | nil, String.t() | nil) ::
          {:ok, binary()} | {:error, {:malformed_state, term()}} | {:error, :step_row_not_found}
  def set_row(raw, id, new_status, evidence_append) do
    with {:ok, state} <- parse(raw),
         %{} = row <- Enum.find(state.steps, &(&1.id == id)) || :not_found do
      status =
        if new_status && row.status != :done, do: new_status, else: row.status_raw

      evidence =
        if evidence_append && not String.contains?(row.evidence, evidence_append) do
          join_evidence(row.evidence, evidence_append)
        else
          row.evidence
        end

      {:ok, rewrite_last_table_rows(raw, fn line -> rebuild_row(line, id, status, evidence) end)}
    else
      :not_found -> {:error, :step_row_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Removes step `id` from the REMAINING note (idempotent: an absent id is a
  no-op). The next listed step inherits the `after`-deps -- the chain
  semantics the parser defines, so selection stays correct after the
  rewrite.
  """
  @spec remove_from_remaining(binary(), String.t()) ::
          {:ok, binary()} | {:error, {:malformed_state, term()}}
  def remove_from_remaining(raw, id) when is_binary(raw) do
    with {:ok, state} <- parse(raw) do
      if Map.has_key?(state.remaining_chain, id) and is_binary(state.remaining_note) do
        {:ok,
         map_lines(raw, fn line ->
           if line =~ ~r/^\s*REMAINING\b/i, do: remove_remaining_item(line, id), else: line
         end)}
      else
        {:ok, raw}
      end
    end
  end

  @spec append_complete_marker(binary(), String.t()) :: binary()
  def append_complete_marker(raw, note) when is_binary(raw) do
    raw
    |> String.trim_trailing("\n")
    |> Kernel.<>(
      "\n\nLOOP COMPLETE #{note} -- wave loop standing down (ultracode-wave-loop/1; " <>
        "REMAINING empty; post-merge CI verified by the closing step worker)\n"
    )
  end

  @doc """
  The loop worker's goal: step id + the step's dispatch instructions
  VERBATIM from STATE.md, the standing section (repo/branch facts), the law
  section (the evidence law), and the mandatory state-update instruction.
  Capped below Run.goal's 50_000-character constraint.
  """
  @spec build_goal(t(), step(), %{
          required(:state_path) => String.t(),
          required(:telemetry_path) => String.t()
        }) :: String.t()
  def build_goal(%__MODULE__{} = state, step, %{state_path: sp, telemetry_path: tp}) do
    step_text = Map.get(state.sections, step.id) || table_row_text(state, step.id)

    """
    You are ONE wave-loop step worker (kind ultracode-wave-loop/1), dispatched \
    by the fabric's hourly Oban schedule. Execute EXACTLY the step below and \
    nothing else.

    === STEP #{step.id}: #{step.name} (status: #{step.status_raw}) ===
    #{String.trim_trailing(step_text || "")}

    === CURRENT STANDING (STATE section (a), verbatim — re-verify every claim \
    against a fresh `git fetch origin` before trusting any SHA) ===
    #{String.trim_trailing(state.standing || "(standing section absent from STATE)")}

    === THE LAW (STATE section (c), verbatim — non-negotiable) ===
    #{String.trim_trailing(state.law || default_law())}

    === ON COMPLETION (mandatory, do BOTH before you finish) ===
    1. Update #{sp}: set this step's row status and fill its DONE evidence \
    with real command+exit evidence. Never leave a step done without evidence.
    2. Append EXACTLY ONE telemetry line to #{tp}:
    {"ts":"<UTC ISO8601>","kind":"ultracode-wave-loop/1","step":"#{step.id}","action":"worker","detail":"<one line>","evidence":"<cmd+exit or artifact path>"}
    """
    |> String.slice(0, 48_000)
  end

  # ------------------------------------------------------------------
  # Internals: table
  # ------------------------------------------------------------------

  defp step_table(lines) do
    headers =
      Enum.with_index(lines)
      |> Enum.filter(fn {line, _i} -> line =~ @step_header_regex end)

    case headers do
      [] ->
        {:error, {:malformed_state, :no_step_table}}

      headers ->
        {_line, idx} = List.last(headers)
        collect_rows(Enum.drop(lines, idx + 1), [])
    end
  end

  defp collect_rows([], acc), do: finish_rows(acc)

  defp collect_rows([line | rest], acc) do
    if String.starts_with?(String.trim_leading(line), "|") do
      case parse_row_line(line) do
        :separator -> collect_rows(rest, acc)
        {:ok, cells} -> collect_rows(rest, [cells | acc])
        :error -> {:error, {:malformed_state, {:bad_table_row, line}}}
      end
    else
      finish_rows(acc)
    end
  end

  defp finish_rows([]), do: {:error, {:malformed_state, :empty_step_table}}
  defp finish_rows(acc), do: {:ok, Enum.reverse(acc)}

  # "| a | b | c |" -> ["a", "b", "c"], with `\|` round-tripping. A line
  # that does not open and close with a pipe is a malformed row.
  defp parse_row_line(line) do
    case String.split(String.replace(line, "\\|", "\u0000"), "|") do
      [head | rest] ->
        cond do
          String.trim(head) != "" or rest == [] ->
            :error

          true ->
            {last, mids} = List.pop_at(rest, -1)

            if String.trim(last) == "" do
              cells =
                Enum.map(mids, fn cell ->
                  cell |> String.trim() |> String.replace("\u0000", "|")
                end)

              cond do
                cells == [] -> :error
                Enum.all?(cells, &separator_cell?/1) -> :separator
                true -> {:ok, cells}
              end
            else
              :error
            end
        end

      [] ->
        :error
    end
  end

  defp separator_cell?(cell), do: cell != "" and cell =~ ~r/^:?-+:?$/

  defp rows_to_steps(rows) do
    Enum.reduce_while(rows, {:ok, []}, fn cells, {:ok, acc} ->
      case row_to_step(cells) do
        {:ok, step} -> {:cont, {:ok, acc ++ [step]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  # Live failed edge (2026-09-21, telemetry tick 1): the coordinator's own
  # writer omits an EMPTY trailing evidence cell -- `| 4 sole-source fold |
  # PENDING — not started |` -- so the real STATE shipped a two-cell row
  # and the first live tick typed it `{:short_step_row, _}` and refused. A
  # two-cell row unambiguously carries id+name+status with empty evidence:
  # accept it as exactly that (narrow shape, no guess); anything SHORTER is
  # still refused.
  defp row_to_step([first, status]) when is_binary(first) and is_binary(status) do
    row_to_step([first, status, ""])
  end

  defp row_to_step([first, status | evidence_cells]) when length(evidence_cells) >= 1 do
    evidence = Enum.join(evidence_cells, " | ")

    case Regex.run(~r/^\s*(\d+)\s*(.*)$/s, first) do
      [_, id, name] ->
        case step(id, name, status, evidence) do
          # Unknown shapes are typed refusals, never guesses: a status the
          # grammar does not know could be anything (done, blocked, or an
          # in-flight claim) and the loop must not pick.
          %{status: :unknown} = unknown ->
            {:error, {:malformed_state, {:unknown_status, id, unknown.status_raw}}}

          parsed ->
            {:ok, parsed}
        end

      nil ->
        {:error, {:malformed_state, {:bad_step_row, first}}}
    end
  end

  defp row_to_step(cells), do: {:error, {:malformed_state, {:short_step_row, cells}}}

  defp step(id, name, status_raw, evidence) do
    status =
      cond do
        done?(status_raw) -> :done
        status_raw =~ ~r/pending/i -> :pending
        status_raw =~ ~r/blocked/i -> :blocked
        true -> :unknown
      end

    %{
      id: id,
      name: String.trim(name),
      status: status,
      status_raw: status_raw,
      evidence: evidence,
      deps: row_deps(status_raw)
    }
  end

  defp done?(raw), do: raw =~ ~r/^\s*done/i or raw =~ ~r/\bcomplete\b/i

  defp row_deps(raw) do
    Regex.scan(~r/BLOCKED[- ]ON[- ]([0-9, +&]+)/i, raw)
    |> Enum.flat_map(fn [_all, ids] -> split_ids(ids) end)
    |> Enum.uniq()
  end

  defp split_ids(raw) do
    raw
    |> then(fn subject -> Regex.scan(~r/\d+/, subject) end)
    |> Enum.map(&hd/1)
    |> Enum.uniq()
  end

  # ------------------------------------------------------------------
  # Internals: the REMAINING note
  # ------------------------------------------------------------------

  defp remaining_note(lines) do
    lines
    |> Enum.filter(&(&1 =~ ~r/^\s*REMAINING\b/i))
    |> List.last()
  end

  defp parse_remaining(nil, _table_ids), do: {:ok, %{}}

  defp parse_remaining(note, table_ids) do
    after_deps =
      case Regex.run(~r/after\s+([0-9, +&]+?)\s*:/i, note) do
        [_, deps] -> split_ids(deps)
        nil -> []
      end

    listed =
      note
      |> then(fn subject -> Regex.scan(@listed_step_regex, subject) end)
      |> Enum.map(&Enum.at(&1, 1))
      |> Enum.uniq()

    if listed == [] do
      {:ok, %{}}
    else
      unknown_listed = Enum.reject(listed, &MapSet.member?(table_ids, &1))
      unknown_deps = Enum.reject(after_deps, &MapSet.member?(table_ids, &1))

      cond do
        unknown_listed != [] ->
          {:error, {:malformed_state, {:remaining_unknown_step, unknown_listed}}}

        unknown_deps != [] ->
          {:error, {:malformed_state, {:unknown_dep, unknown_deps}}}

        true ->
          chain =
            listed
            |> Enum.with_index()
            |> Map.new(fn {id, i} ->
              deps = if i == 0, do: after_deps, else: [Enum.at(listed, i - 1)]
              {id, deps}
            end)

          {:ok, chain}
      end
    end
  end

  # ------------------------------------------------------------------
  # Internals: sections
  # ------------------------------------------------------------------

  defp extract_sections(lines) do
    %{
      step_sections: step_sections(lines),
      standing: section_body(lines, ~r/^##\s*\(a\)/i),
      law: section_body(lines, ~r/^##\s*\(c\)/i)
    }
  end

  # `### [<id>] <title>` blocks, verbatim, up to the next heading or `---`.
  defp step_sections(lines) do
    lines
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {line, i}, acc ->
      case Regex.run(~r/^###\s*\[(\d+)\]/, line) do
        [_, id] -> Map.put(acc, id, Enum.join(section_slice(lines, i), "\n"))
        nil -> acc
      end
    end)
  end

  defp section_body(lines, header_regex) do
    lines
    |> Enum.with_index()
    |> Enum.find(fn {line, _i} -> line =~ header_regex end)
    |> case do
      nil -> nil
      {_line, i} -> Enum.join(section_slice(lines, i), "\n")
    end
  end

  # From the header at `i` up to (not including) the next `###`/`## `
  # heading or a `---` rule.
  defp section_slice(lines, i) do
    body =
      lines
      |> Enum.drop(i + 1)
      |> Enum.take_while(fn line ->
        trimmed = String.trim_leading(line)
        not (trimmed =~ ~r/^###/ or trimmed =~ ~r/^## / or trimmed == "---")
      end)

    [Enum.at(lines, i) | body]
  end

  # ------------------------------------------------------------------
  # Internals: rendering
  # ------------------------------------------------------------------

  defp map_lines(raw, fun),
    do: raw |> String.split(["\r\n", "\n"]) |> Enum.map(fun) |> Enum.join("\n")

  # Rewrites rows ONLY inside the LAST step table (an older superseded
  # table elsewhere in the file must stay untouched).
  defp rewrite_last_table_rows(raw, fun) do
    lines = String.split(raw, ["\r\n", "\n"])

    last_header =
      lines
      |> Enum.with_index()
      |> Enum.filter(fn {line, _i} -> line =~ @step_header_regex end)
      |> List.last()
      |> case do
        nil -> nil
        {_line, idx} -> idx
      end

    {before, from} = Enum.split(lines, last_header + 1)

    {table, rest_lines} =
      Enum.split_while(from, fn line -> String.starts_with?(String.trim_leading(line), "|") end)

    Enum.join(before ++ Enum.map(table, fun) ++ rest_lines, "\n")
  end

  defp rebuild_row(line, id, status, evidence) do
    case {row_id(line), parse_row_line(line)} do
      {^id, {:ok, [_first | _rest]}} ->
        "| #{row_name(line)} | #{escape_cell(status)} | #{escape_cell(evidence)} |"

      _ ->
        line
    end
  end

  # The leading integer of a table row's first cell, or nil.
  defp row_id(line) do
    if String.starts_with?(String.trim_leading(line), "|") do
      case parse_row_line(line) do
        {:ok, [first | _]} ->
          case Regex.run(~r/^(\d+)\b/, first) do
            [_, id] -> id
            nil -> nil
          end

        _ ->
          nil
      end
    else
      nil
    end
  end

  # The first cell verbatim: "<id> <name>".
  defp row_name(line) do
    case parse_row_line(line) do
      {:ok, [first | _]} -> first
      _ -> ""
    end
  end

  defp join_evidence(existing, append)
  defp join_evidence("", append), do: append
  defp join_evidence(existing, append), do: existing <> " — " <> append

  defp escape_cell(text), do: String.replace(text, "|", "\\|")

  # Drop `step <id> <desc>` from the note, plus ONE adjoining connector, so
  # the remaining chain stays parseable and the next first step inherits the
  # after-deps. Cosmetic leftovers collapse to the ": none." form.
  defp remove_remaining_item(line, id) do
    cleaned =
      String.replace(
        line,
        ~r/\s*,?\s*(?:then\s+)?step\s+#{id}\b[^,.;]*(?:\s*,?\s*then\b)?/i,
        ""
      )

    cleaned
    |> String.replace(~r/:\s*,\s*(?=\S)/, ": ")
    |> String.replace(~r/:\s*\.\s*Then/i, ": none. Then")
    |> String.replace(~r/:\s*\.$/, ": none.")
  end

  defp table_row_text(%__MODULE__{steps: steps}, id) do
    case Enum.find(steps, &(&1.id == id)) do
      %{id: ^id, name: name, status_raw: status, evidence: evidence} ->
        "| #{id} #{name} | #{status} | #{evidence} |"

      _ ->
        nil
    end
  end

  defp default_law do
    """
    1. Never force-push; on push rejection: fetch, rebase, retry <=3, then BLOCKED + record. Never touch main.
    2. Never write operator checkouts directly; all work happens in worktrees cut from fetched origin tips.
    3. Evidence law: every claim carries command + exit code. No acceptance mocks, no weakened tests, no placeholders on changed production paths.
    4. Refusal is a valid outcome; record BLOCKED with the refusal record preserved. Failed edges are evidence.
    """
  end
end
