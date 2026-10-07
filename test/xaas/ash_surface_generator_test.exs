defmodule Xaas.AshSurfaceGeneratorTest do
  @moduledoc """
  X8 gap #1: xaas-side generator test (v26.10.6 convergence).

  Runs the real full-app generation pipeline in-process via the mix task with a
  `--target-dir` override into a per-test temp dir, then:

    * asserts the .mjs artifacts are produced and `node --check`-clean
      (real node subprocess, no mocks);
    * asserts the EA35 falsifier shape: namespace_prefix "Xaas" applied on the
      full-app run — a namespaced identifier (e.g. `XaasToken`) appears in the
      generated client and the task returns :ok (no `{:unsafe_js_namespace,
      "Object"}` refusal);
    * asserts the committed `priv/ash_surface/` artifacts are untouched
      (digest before == after; the test generates only into temp).
  """

  use ExUnit.Case, async: false

  @out_dir "priv/ash_surface"
  @committed_artifacts [
    "surface_contract.json",
    "live_view.json",
    "aria.json",
    "xaas_ash_surface_client.mjs",
    "ash_surface_runtime.mjs"
  ]

  @tag :ash_surface_gen
  test "full-app generation into temp target_dir yields node-clean namespaced .mjs artifacts" do
    committed_before = digest_committed()

    target_dir =
      Path.join(
        System.tmp_dir!(),
        "xaas_ash_surface_gen_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(target_dir)
    on_exit(fn -> File.rm_rf!(target_dir) end)

    # Real in-process run of the mix task (app already started under MIX_ENV=test).
    io =
      ExUnit.CaptureIO.capture_io(fn ->
        assert :ok == Mix.Task.rerun("xaas.ash_surface", ["--target-dir", target_dir])
      end)

    assert io =~ "ash_surface generation complete"

    client = Path.join(target_dir, "xaas_ash_surface_client.mjs")
    runtime = Path.join(target_dir, "ash_surface_runtime.mjs")

    for artifact <- [client, runtime] do
      assert File.exists?(artifact), "expected #{artifact} to be produced"
    end

    # EA35 falsifier shape: namespace_prefix "Xaas" applied on full-app run.
    client_src = File.read!(client)
    assert client_src =~ "XaasToken"
    assert client_src =~ "XaasUser"

    # Real node syntax gate on every generated .mjs.
    for js <- [client, runtime] do
      assert {_, 0} =
               System.cmd("node", ["--check", js],
                 stderr_to_stdout: true,
                 into: IO.stream(:stdio, :line)
               )
    end

    # Committed artifacts untouched: test generated only into temp.
    assert digest_committed() == committed_before
  end

  defp digest_committed do
    for name <- @committed_artifacts do
      path = Path.join(@out_dir, name)
      assert File.exists?(path), "committed artifact missing: #{path}"
      {name, sha256(path)}
    end
  end

  defp sha256(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, io} ->
        hash = :crypto.hash_init(:sha256) |> hash_stream(io) |> :crypto.hash_final()
        File.close(io)
        Base.encode16(hash, case: :lower)

      {:error, reason} ->
        flunk("could not open #{path}: #{inspect(reason)}")
    end
  end

  defp hash_stream(hash, io) do
    case IO.binread(io, 65_536) do
      :eof -> hash
      {:error, reason} -> flunk("read error on committed artifact: #{inspect(reason)}")
      chunk -> hash |> :crypto.hash_update(chunk) |> hash_stream(io)
    end
  end
end
