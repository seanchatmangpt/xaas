#!/usr/bin/env elixir
# AIRo pin-drift check (W981w). Standalone: no repo code deps, System.cmd git only.
#
# Parses the ledger's fleet-SHA tables (any `| repo | ... | <40-hex> | ...` row),
# then for each row runs, in ~/<repo>:
#   1. git rev-parse HEAD
#   2. git merge-base --is-ancestor <recorded> HEAD   (only when HEAD != recorded)
# Status per row:
#   CURRENT   recorded == HEAD
#   ANCESTOR  recorded is an ancestor of HEAD (fast-forwarded since the pin)
#   DRIFT     recorded is NOT an ancestor of HEAD (history diverged)
#   MISSING   repo absent on disk or not a git repo
#
# Emits one JSON object on stdout. Exit 0 unless the ledger itself is unparseable.
# DRIFT is reported, not failed — the ExUnit wrapper (test/xaas/airo/pin_drift_test.exs)
# asserts the receipt's drift table matches this reality.

ledger =
  case System.argv() do
    [path | _] -> path
    [] -> Path.expand("docs/cro/artifacts/airo-wiring-ledger.md", File.cwd!())
  end

home = System.user_home!()

rows =
  ledger
  |> File.read!()
  |> String.split(["\r\n", "\n"])
  |> Enum.flat_map(fn line ->
    line = String.trim(line)

    if String.starts_with?(line, "|") do
      cells = line |> String.trim("|") |> String.split("|") |> Enum.map(&String.trim/1)

      case cells do
        [repo_cell | rest] ->
          sha =
            Enum.find_value(rest, fn c ->
              case Regex.run(~r/^`([0-9a-f]{40})`$/, c) do
                [_, sha] -> sha
                _ -> nil
              end
            end)

          repo =
            repo_cell
            |> String.replace_prefix("`", "")
            |> String.replace_suffix("`", "")
            |> String.replace(~r/\s*\(submodule\)\s*$/, "")

          cond do
            is_nil(sha) -> []
            repo in ["repo", "lane", "file", ""] -> []
            String.starts_with?(repo, ":") or String.starts_with?(repo, "-") -> []
            true -> [{repo, sha}]
          end

        _ ->
          []
      end
    else
      []
    end
  end)
|> Enum.uniq_by(fn {repo, _} -> repo end)

if rows == [], do: raise("no ledger rows parsed from #{ledger}")

results =
  Enum.map(rows, fn {repo, recorded} ->
    path = Path.join(home, repo)

    cond do
      not File.dir?(Path.join(path, ".git")) and not File.exists?(Path.join(path, ".git")) ->
        %{repo: repo, recorded: recorded, head: nil, status: "MISSING"}

      true ->
        case System.cmd("git", ["-C", path, "rev-parse", "HEAD"], stderr_to_stdout: true) do
          {head, 0} ->
            head = String.trim(head)

            if head == recorded do
              %{repo: repo, recorded: recorded, head: head, status: "CURRENT"}
            else
              ancestor? =
                match?({_, 0}, System.cmd("git", ["-C", path, "merge-base", "--is-ancestor", recorded, "HEAD"], stderr_to_stdout: true))

              %{repo: repo, recorded: recorded, head: head, status: if(ancestor?, do: "ANCESTOR", else: "DRIFT")}
            end

          {err, _} ->
            %{repo: repo, recorded: recorded, head: String.trim(err), status: "MISSING"}
        end
    end
  end)

drift = Enum.filter(results, &(&1.status == "DRIFT"))

# Minimal JSON encoder (standalone script: no Jason/Hex deps available).
defmodule PinDriftJson do
  def enc(v) when is_binary(v), do: ~s(") <> escape(v) <> ~s(")
  def enc(v) when is_integer(v), do: Integer.to_string(v)
  def enc(true), do: "true"
  def enc(false), do: "false"
  def enc(nil), do: "null"
  def enc(v) when is_list(v), do: "[" <> Enum.map_join(v, ",", &enc/1) <> "]"

  def enc(v) when is_map(v),
    do: "{" <> Enum.map_join(v, ",", fn {k, val} -> enc(to_string(k)) <> ":" <> enc(val) end) <> "}"

  defp escape(s), do: s |> String.replace("\\", "\\\\") |> String.replace("\"", "\\\"") |> String.replace("\n", "\\n")
end

report = %{
  ledger: ledger,
  generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
  rows_checked: length(results),
  counts: %{
    current: Enum.count(results, &(&1.status == "CURRENT")),
    ancestor: Enum.count(results, &(&1.status == "ANCESTOR")),
    drift: length(drift),
    missing: Enum.count(results, &(&1.status == "MISSING"))
  },
  results: results,
  drift: drift
}

IO.puts(PinDriftJson.enc(report))
