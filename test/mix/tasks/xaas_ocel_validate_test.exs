defmodule Mix.Tasks.Xaas.OcelValidateTest do
  @moduledoc """
  Real subprocess qualification of `mix xaas.ocel_validate`: real files on
  disk, a real OS-process `mix` run (`System.cmd/3`, nested BEAM boot, hence
  the `:subprocess` tag -- excluded from the default fast loop per
  test/test_helper.exs), and real process exit codes. Nothing mocked.
  """

  use ExUnit.Case, async: false

  @valid_log ~s({
    "ocel:objectTypes": ["order", "item"],
    "ocel:eventTypes": ["order_placed", "item_picked"],
    "ocel:events": [
      {
        "id": "e1",
        "type": "order_placed",
        "time": "2026-09-19T09:00:00Z",
        "attributes": {"channel": "web"},
        "relationships": [{"objectId": "o1", "qualifier": "places"}]
      },
      {
        "id": "e2",
        "type": "item_picked",
        "time": "2026-09-19T09:05:00Z",
        "attributes": {},
        "relationships": [{"objectId": "i1", "qualifier": "picks"}]
      }
    ],
    "ocel:objects": [
      {"id": "o1", "type": "order", "attributes": {"total": 42}},
      {"id": "i1", "type": "item", "attributes": {}}
    ]
  })

  # Same log, tampered: a rogue event with an undeclared type, plus a
  # dangling relationship. Exit 1 must name BOTH violations.
  @tampered_log ~s({
    "ocel:objectTypes": ["order", "item"],
    "ocel:eventTypes": ["order_placed", "item_picked"],
    "ocel:events": [
      {
        "id": "e1",
        "type": "order_placed",
        "time": "2026-09-19T09:00:00Z",
        "attributes": {},
        "relationships": [{"objectId": "ghost-object", "qualifier": "places"}]
      },
      {
        "id": "e2",
        "type": "worker_launched",
        "time": "2026-09-19T09:05:00Z",
        "attributes": {}
      }
    ],
    "ocel:objects": [
      {"id": "o1", "type": "order", "attributes": {}}
    ]
  })

  @tag :subprocess
  test "a valid log exits 0 and prints the verdict with counts" do
    path = write_tmp("valid.json", @valid_log)

    {output, 0} = run_task([path])
    assert output =~ ": valid (2 events, 2 objects)"
  end

  @tag :subprocess
  test "a tampered log exits 1 and prints each violation with its exact JSON path" do
    path = write_tmp("tampered.json", @tampered_log)

    {output, 1} = run_task([path])

    assert output =~
             "ocel:events[0].relationships[0].objectId objectId 'ghost-object' does not resolve"

    assert output =~ "ocel:events[1].type 'worker_launched' not declared in ocel:eventTypes"
  end

  @tag :subprocess
  test "--quiet exits 0 with no court output on a valid log" do
    path = write_tmp("valid_quiet.json", @valid_log)

    {output, 0} = run_task([path, "--quiet"])
    # The court itself must be silent; unrelated compiler diagnostics replayed
    # by Mix from OTHER files on the base head (e.g. export_ocel.ex, untouched
    # by this diff) are not this task's output and may legitimately appear.
    refute output =~ ": valid"
    refute output =~ "ocel:"
  end

  @tag :subprocess
  test "--quiet exits 1 with no court output on an invalid log (the exit code alone carries the verdict)" do
    path = write_tmp("tampered_quiet.json", @tampered_log)

    {output, 1} = run_task([path, "--quiet"])
    refute output =~ "ocel:"
    refute output =~ ": valid"
  end

  @tag :subprocess
  test "a missing file exits 1 with a fail-closed violation" do
    {output, 1} = run_task(["/nonexistent/w3_ocel_court_missing.json"])
    assert output =~ "cannot read file"
  end

  @tag :subprocess
  test "bad usage (no path) exits 1 with the usage line" do
    {output, 1} = run_task([])
    assert output =~ "usage: mix xaas.ocel_validate <path> [--quiet]"
  end

  @tag :subprocess
  test "an unknown flag exits 1 with the usage line (fail-closed CLI)" do
    path = write_tmp("valid_unknown_flag.json", @valid_log)

    {output, 1} = run_task([path, "--quite"])
    assert output =~ "unknown options"
    assert output =~ "usage: mix xaas.ocel_validate <path> [--quiet]"
  end

  defp run_task(args) do
    System.cmd("mix", ["xaas.ocel_validate" | args],
      cd: File.cwd!(),
      env: %{"MIX_ENV" => "test"},
      stderr_to_stdout: true
    )
  end

  defp write_tmp(name, body) do
    path =
      Path.join(
        System.tmp_dir!(),
        "w3_ocel_court_task_#{System.unique_integer([:positive])}_#{name}"
      )

    File.write!(path, body)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
