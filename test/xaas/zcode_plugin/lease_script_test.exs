defmodule Xaas.ZcodePlugin.LeaseScriptTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Real Chicago-style qualification for `scripts/xaas-lease.mjs`'s `save`
  command -- the client-side half of the zcode plugin projected by ggen from
  `priv/zcode_plugin/templates/script-xaas-lease.mjs.tmpl`, exercised as the
  committed projection
  (`priv/zcode_plugin/marketplace/xaas-fabric/scripts/xaas-lease.mjs`)
  executed by a real `node` subprocess against a real state file on disk -- nothing mocked or stubbed.

  Regression guard for a real client-side bug: `saveLease`/`xaas-lease.mjs
  save` used to unconditionally overwrite the lease state file for a cwd,
  with no check against a still-live lease already held under a different
  lease_token. The server-side claim (`Xaas.Ultracode.Lease.claim_next/3`)
  is race-safe by construction (a single filtered bulk UPDATE -- see
  lease_test.exs), but nothing stopped a second `claim_next` + `save` in the
  same worktree from silently clobbering the first worker's only capability
  on the client side. `save` now refuses (exit 65) unless the existing
  lease is absent, expired, the same token (a renewal), or `--force` is
  passed explicitly.
  """

  @script_source "priv/zcode_plugin/marketplace/xaas-fabric/scripts/xaas-lease.mjs"

  setup_all do
    rendered = File.read!(@script_source)

    script_path =
      Path.join(
        System.tmp_dir!(),
        "xaas-lease-under-test-#{System.unique_integer([:positive])}.mjs"
      )

    File.write!(script_path, rendered)

    on_exit(fn -> File.rm(script_path) end)

    %{script_path: script_path}
  end

  setup %{script_path: script_path} do
    # The script's own state file lives OUTSIDE this `cwd` dir, in the
    # OS-shared `<tmpdir>/xaas-fabric/<sha256(cwd)>.json`, keyed only by the
    # cwd string. A `System.unique_integer/1` counter restarts at 1 on every
    # fresh `mix test` BEAM VM, so across separate test invocations the same
    # small integer -- and therefore the same cwd string and the same
    # sha256-derived state-file path -- can recur, leaking a prior run's
    # lease state into this one. Force a clean slate for real via the
    # script's own `clear` command rather than assuming uniqueness holds.
    cwd =
      Path.join(
        System.tmp_dir!(),
        "xaas-lease-cwd-#{System.unique_integer([:positive])}-#{System.os_time(:nanosecond)}"
      )

    File.mkdir_p!(cwd)
    System.cmd("node", [script_path, "clear"], cd: cwd)
    on_exit(fn -> File.rm_rf(cwd) end)

    %{script_path: script_path, cwd: cwd}
  end

  defp lease_json(token, expires_at) do
    Jason.encode!(%{
      "lease_token" => token,
      "lease_expires_at" => DateTime.to_iso8601(expires_at),
      "epoch_id" => "epoch-#{token}"
    })
  end

  defp run(script_path, cwd, args) do
    System.cmd("node", [script_path | args], cd: cwd, stderr_to_stdout: true)
  end

  test "save refuses to clobber a live lease held under a different token, without --force", %{
    script_path: script_path,
    cwd: cwd
  } do
    far_future = DateTime.add(DateTime.utc_now(), 1800, :second)

    {out_a, 0} = run(script_path, cwd, ["save", lease_json("token-a", far_future)])
    assert out_a =~ "saved"

    {get_after_a, 0} = run(script_path, cwd, ["get"])
    assert Jason.decode!(get_after_a)["lease_token"] == "token-a"

    {out_b, exit_code} = run(script_path, cwd, ["save", lease_json("token-b", far_future)])
    assert exit_code == 65
    assert out_b =~ "lease_conflict"

    # Real, load-bearing assertion: the state file on disk was NOT clobbered.
    {get_after_conflict, 0} = run(script_path, cwd, ["get"])
    assert Jason.decode!(get_after_conflict)["lease_token"] == "token-a"

    {out_forced, 0} =
      run(script_path, cwd, ["save", lease_json("token-b", far_future), "--force"])

    assert out_forced =~ "saved"

    {get_after_force, 0} = run(script_path, cwd, ["get"])
    assert Jason.decode!(get_after_force)["lease_token"] == "token-b"
  end

  test "save allows overwriting an already-expired lease without --force", %{
    script_path: script_path,
    cwd: cwd
  } do
    already_expired = DateTime.add(DateTime.utc_now(), -60, :second)
    far_future = DateTime.add(DateTime.utc_now(), 1800, :second)

    {_out, 0} = run(script_path, cwd, ["save", lease_json("token-expired", already_expired)])

    {_out, 0} = run(script_path, cwd, ["save", lease_json("token-fresh", far_future)])

    {get_result, 0} = run(script_path, cwd, ["get"])
    assert Jason.decode!(get_result)["lease_token"] == "token-fresh"
  end

  test "save allows re-saving the same lease_token (renewal) without --force", %{
    script_path: script_path,
    cwd: cwd
  } do
    expires_soon = DateTime.add(DateTime.utc_now(), 1800, :second)
    renewed_expiry = DateTime.add(DateTime.utc_now(), 3600, :second)

    {_out, 0} = run(script_path, cwd, ["save", lease_json("token-same", expires_soon)])
    {out, 0} = run(script_path, cwd, ["save", lease_json("token-same", renewed_expiry)])
    assert out =~ "saved"

    {get_result, 0} = run(script_path, cwd, ["get"])
    decoded = Jason.decode!(get_result)
    assert decoded["lease_token"] == "token-same"
    assert decoded["lease_expires_at"] == DateTime.to_iso8601(renewed_expiry)
  end

  test "save with no prior lease for this cwd never conflicts", %{
    script_path: script_path,
    cwd: cwd
  } do
    far_future = DateTime.add(DateTime.utc_now(), 1800, :second)
    {out, 0} = run(script_path, cwd, ["save", lease_json("token-first", far_future)])
    assert out =~ "saved"
  end
end
