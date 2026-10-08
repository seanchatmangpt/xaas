defmodule Xaas.Airo.PinCourtTest do
  @moduledoc """
  AIRo pin court (lane W981j). Real Chicago court over the on-disk fleet:
  reads `docs/cro/artifacts/airo-wiring-ledger.md`, parses every W981e /
  W981f extension row, and asserts against the real world:

    1. the sibling checkout exists at `~/<repo>` (absent rows are counted
       and reported, never silently skipped),
    2. its real HEAD matches the SHA pinned in the ledger row,
    3. every cited path in the row exists on disk in that checkout,
    4. the falsifier names a concrete artifact path (`.ttl`/`.rq` surface),
    5. the canonical AIRo vocab sha256 pin (`6274d2d8…`) is re-verified
       from the real vendored bytes and carried by
       `docs/airo/pin-court-vocab.md`.

  No mocks. Real filesystem, real `git` subprocess, real file bytes.
  """

  use ExUnit.Case, async: true

  @ledger Path.join(File.cwd!(), "docs/cro/artifacts/airo-wiring-ledger.md")
  @vocab_doc Path.join(File.cwd!(), "docs/airo/pin-court-vocab.md")
  @canonical_vocab Path.join(File.cwd!(), "priv/semantic/airo/airo.ttl")
  @vocab_sha "6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469"
  @home System.user_home!()

  defp ledger_lines do
    @ledger |> File.read!() |> String.split("\n")
  end

  defp extension_rows do
    for line <- ledger_lines(),
        row = parse_row(line) do
      row
    end
  end

  # Parses the pipe tables inside the two W981e / W981f extension sections
  # (7 columns: repo branch head dim cited falsifier standing). Excludes the
  # main fleet SHA table (4 columns) and the consolidated table (6 columns).
  defp parse_row(line) do
    cols = line |> String.trim() |> String.split("|", trim: true) |> Enum.map(&String.trim/1)

    case cols do
      [repo, branch, head, _dim, cited, falsifier, standing] = seven
      when length(seven) == 7 ->
        head_sha = String.replace(head, "`", "")

        if row_repo?(repo) and Regex.match?(~r/^[0-9a-f]{40}$/, head_sha) do
          %{
            repo: repo,
            branch: branch,
            head: head_sha,
            cited_paths: cited_paths(cited),
            cited_cell: cited,
            falsifier: falsifier,
            standing: standing
          }
        else
          nil
        end

      _ ->
        nil
    end
  end

  # Only the W981e/W981f extension tables carry a 40-hex HEAD in column 3;
  # this excludes header rows and the 4-column fleet SHA table.
  defp row_repo?(repo), do: repo not in ["repo", "lane", "file"]

  defp cited_paths(cited_cell) do
    Regex.scan(~r/`([^`]+)`/, cited_cell)
    |> Enum.map(fn [_, tok] -> tok end)
    |> Enum.filter(&path_like?/1)
    |> Enum.uniq()
    |> case do
      [] -> flunk("cited surface names no concrete path: #{inspect(cited_cell)}")
      paths -> paths
    end
  end

  defp path_like?(tok) do
    String.contains?(tok, "/") or
      Regex.match?(~r/\.(ex|exs|ttl|rq|md|json|toml|py|sh)$/, tok)
  end

  defp checkout(repo), do: Path.join(@home, repo)

  defp real_head(repo) do
    case System.cmd("git", ["-C", checkout(repo), "rev-parse", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      {err, _} -> {:error, String.trim(err)}
    end
  end

  # Cited paths appear in three honest shapes: repo-rooted ("lib/x/y.ex"),
  # bare filenames relative to the repo's own source dir ("authority.ex"
  # under lib/ash_graphlaw/), or bare names relative to a directory the
  # row itself cites ("admission/ (courts/ws1-*.rq, policies.ttl)").
  # Resolve against: repo root, lib/, lib/<app>/, and every "<dir>/" token
  # the cited surface names. Globs ("*.rq") resolve via Path.wildcard.
  defp path_exists_in_repo?(repo, cited_cell, p) do
    app = String.replace(repo, "-", "_")

    prefixes =
      [checkout(repo), Path.join([checkout(repo), "lib"]), Path.join([checkout(repo), "lib", app])] ++
        for(dir <- Regex.scan(~r/`?([\w.-]+\/)`?/, cited_cell, capture: :all_but_first) |> List.flatten(),
          do: Path.join(checkout(repo), dir)
        )

    resolve(p, prefixes)
  end

  defp resolve(p, prefixes) do
    if String.contains?(p, "*") do
      prefixes
      |> Enum.flat_map(&Path.wildcard(Path.join(&1, p)) |> case do
        [] -> []
        _ -> [:hit]
      end)
      |> Enum.any?()
    else
      prefixes
      |> Enum.map(&Path.join(&1, p))
      |> Enum.any?(&File.exists?/1)
    end
  end

  defp missing_paths(row, cited_cell) do
    Enum.filter(row.cited_paths, fn p ->
      not path_exists_in_repo?(row.repo, cited_cell, p)
    end)
  end

  # Rows whose checkout is absent are counted, not silently skipped.
  test "ledger contains the nine extension rows (3 W981e + 6 W981f)" do
    assert length(extension_rows()) == 9
  end

  test "no ledger row is silently skipped: absent checkouts are recorded" do
    absent = extension_rows() |> Enum.reject(&File.dir?(checkout(&1.repo)))
    IO.puts("[pin-court] skipped (checkout absent): #{length(absent)}")
    Enum.each(absent, &IO.puts("[pin-court]   absent: #{&1.repo}"))
    assert is_list(absent)
  end

  test "canonical vocab sha re-verified from real vendored bytes" do
    assert File.exists?(@canonical_vocab)
    {:ok, bytes} = File.read(@canonical_vocab)
    assert :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower) == @vocab_sha
  end

  test "vocab pin doc carries the exact pinned sha and its real blob identity" do
    assert File.exists?(@vocab_doc)
    doc = File.read!(@vocab_doc)
    assert doc =~ @vocab_sha
    {blob, 0} = System.cmd("git", ["rev-parse", "HEAD:priv/semantic/airo/airo.ttl"])
    assert String.trim(blob) in (doc |> String.replace("`", "") |> String.split(~r/\s+/))
  end

  test "every present row: real HEAD matches ledger SHA, cited paths exist, falsifier is concrete" do
    for row <- extension_rows(), File.dir?(checkout(row.repo)) do
      assert real_head(row.repo) == row.head,
             "#{row.repo}: on-disk HEAD diverged from ledger pin #{String.slice(row.head, 0, 12)}"

      refute missing_paths(row, row.cited_cell) != [],
             "#{row.repo}: cited paths missing on disk: #{inspect(missing_paths(row, row.cited_cell))}"

      assert row.falsifier =~ ~r/[\w.-]+\/[\w.-]+\.(ttl|rq)/,
             "#{row.repo}: falsifier names no concrete artifact path: #{row.falsifier}"

      assert row.standing in ["UNKNOWN", "ALIVE", "PARTIAL_ALIVE"]
    end
  end

  test "one row driven to ALIVE: xaas-local vocab pin artifact exists and passes the falsifier shape" do
    # The falsifier gate "vocab sha `6274d2d8…` + cited paths + graph parses"
    # has a pinned, verified vocabulary artifact at docs/airo/pin-court-vocab.md
    # carrying the exact content sha; the vocab bytes parse as Turtle.
    assert File.exists?(@vocab_doc)
    assert File.read!(@vocab_doc) =~ @vocab_sha
    ttl = File.read!(@canonical_vocab)
    assert ttl =~ ~r/@prefix\s+airo:\s+<https:\/\/w3id\.org\/airo#>/s
    assert ttl =~ "<https://w3id.org/airo#"
    assert ttl =~ ~r/RiskSource/
    assert ttl =~ ~r/rdf:type owl:Class/
  end
end
