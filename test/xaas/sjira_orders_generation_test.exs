defmodule Xaas.SjiraOrdersGenerationTest do
  @moduledoc """
  Guard: the Semantic Jira order files under `docs/sjira/v26.9.21/` are generator output.

  `generate.py` writes `NNN-*.md` and `index.json`; observed standing, ticked DoD boxes and
  the Receipts section are generator inputs under `standing/`. Before this guard, SJ-004 was
  hand-edited to ALIVE and the checked-in order file diverged from what `generate.py`
  produces, so a regeneration silently dropped the receipts and left ALIVE with unticked
  boxes. Real subprocess (`python3`), real files on disk, byte-for-byte state assertions,
  no doubles. Skipped by name when `python3` is not installed.
  """
  use ExUnit.Case, async: true

  @dir "docs/sjira/v26.9.21"
  @generator Path.join(@dir, "generate.py")
  @python System.find_executable("python3")

  if is_nil(@python), do: @moduletag(skip: "python3 not installed: cannot run generate.py")

  defp scratch(tag) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "sjira-gen-#{tag}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp generate(out, standing_dir) do
    System.cmd(@python, [@generator],
      env: [
        {"SJIRA_OUT", out},
        {"SJIRA_STANDING", standing_dir},
        {"WO_JSON", Path.join(out, "wo.json")}
      ],
      stderr_to_stdout: true
    )
  end

  defp order_files do
    Path.wildcard(Path.join(@dir, "[0-9][0-9][0-9]-*.md"))
    |> Enum.reject(&String.ends_with?(&1, "000-survey.md"))
    |> Enum.map(&Path.basename/1)
    |> Enum.concat(["index.json"])
    |> Enum.sort()
  end

  # Files under `checked_in_dir` whose bytes differ from the regenerated copy under `out`.
  defp diverged(checked_in_dir, out) do
    for file <- order_files(),
        File.read!(Path.join(checked_in_dir, file)) != File.read!(Path.join(out, file)),
        do: file
  end

  test "regenerating from generate.py and standing/ reproduces every checked-in order byte for byte" do
    out = scratch("regen")
    assert {_out, 0} = generate(out, Path.join(@dir, "standing"))

    files = order_files()
    assert length(files) == 14, "expected the thirteen cycle orders plus index.json, got #{inspect(files)}"

    assert diverged(@dir, out) == [],
           "generated output was hand-edited. Put observed standing/ticks/receipts in " <>
             "#{@dir}/standing/ and regenerate."
  end

  test "every order that claims ALIVE has all DoD boxes ticked and a Receipts section" do
    alive =
      for file <- order_files(),
          file != "index.json",
          body = File.read!(Path.join(@dir, file)),
          String.contains?(body, "\n- **Standing**: ALIVE"),
          do: {file, body}

    assert alive != [], "expected at least SJ-004 to stand ALIVE"

    for {file, body} <- alive do
      refute body =~ "- [ ] ", "#{file}: ALIVE with an unticked DoD box"
      assert body =~ "\n## Receipts\n", "#{file}: ALIVE without a Receipts section"
    end
  end

  test "index.json standing agrees with the order file front matter" do
    index = @dir |> Path.join("index.json") |> File.read!() |> Jason.decode!()

    for %{"path" => path, "standing" => standing} <- index do
      body = File.read!(Path.join(@dir, path))
      assert body =~ ~s("standing": "#{standing}"), "#{path}: index says #{standing}"
    end
  end

  test "the generator refuses ALIVE with unticked DoD items" do
    standing = scratch("unticked")
    out = scratch("unticked-out")

    File.write!(
      Path.join(standing, "004.json"),
      ~s({"standing":"ALIVE","done":[0],"receipts":"004.receipts.md"})
    )

    File.write!(Path.join(standing, "004.receipts.md"), "## Receipts\n\nx\n")

    assert {output, code} = generate(out, standing)
    assert code != 0
    assert output =~ "ALIVE with 2 unticked DoD item(s)"
  end

  test "the generator refuses ALIVE without a Receipts section" do
    standing = scratch("noreceipts")
    out = scratch("noreceipts-out")

    File.write!(
      Path.join(standing, "004.json"),
      ~s({"standing":"ALIVE","done":[0,1,2],"receipts":"004.receipts.md"})
    )

    File.write!(Path.join(standing, "004.receipts.md"), "just prose, no heading\n")

    assert {output, code} = generate(out, standing)
    assert code != 0
    assert output =~ "ALIVE without a receipts section"
  end

  test "a hand-edit of a generated order (ticked box) is detected as divergence" do
    out = scratch("handedit-out")
    copy = scratch("handedit-copy")
    assert {_out, 0} = generate(out, Path.join(@dir, "standing"))

    for file <- order_files(), do: File.cp!(Path.join(@dir, file), Path.join(copy, file))
    assert diverged(copy, out) == []

    order = "003-handwritten-paydown-zcode-plugin.md"  # a PARTIAL_ALIVE order still has an unticked box
    path = Path.join(copy, order)
    File.write!(path, String.replace(File.read!(path), "- [ ] ", "- [x] ", global: false))

    assert diverged(copy, out) == [order]
  end
end
