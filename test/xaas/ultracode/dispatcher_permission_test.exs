defmodule Xaas.Ultracode.DispatcherPermissionTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Exact-argv court for the standing shell compatibility dispatcher.

  The semantic path delegates permission posture to zcode-cli gall-work,
  whose own qualification pins the constructed runtime turn to
  `--mode yolo`. This court attacks the older non-semantic /xaas prompt
  path directly so unattended XaaS dispatch cannot silently regress to
  ZCode's interactive build-mode permission broker.
  """

  @script Path.expand("../../../scripts/xaas-glm-failover-dispatcher.sh", __DIR__)

  test "non-semantic compatibility dispatch pins --mode yolo" do
    root =
      Path.join(
        System.tmp_dir!(),
        "dispatcher-permission-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    cli = Path.join(root, "cli")
    state = Path.join(root, "state")
    worktree = Path.join(root, "worktree")
    capture = Path.join(root, "argv.txt")

    File.mkdir_p!(cli)
    File.mkdir_p!(state)
    File.mkdir_p!(worktree)

    on_exit(fn -> File.rm_rf(root) end)

    shell = ~S"""
    set -eu
    eval "$(sed -n '/^dispatch_one_epoch()/,/^}/p' "$SCRIPT")"

    log() { :; }

    run_with_timeout() {
      printf '%s\n' "$@" > "$CAPTURE"
      return 0
    }

    ZCODE_CLI_DIR="$CLI"
    ZCODE_BIN="bin/zcode.js"
    STATE_DIR="$STATE"
    DISPATCH_TIMEOUT=30
    DISPATCH_RESULT=1

    dispatch_one_epoch \
      "11111111-1111-1111-1111-111111111111" \
      "$WORKTREE" "" "" "" "" ""

    cat "$CAPTURE"
    """

    assert {out, 0} =
             System.cmd("bash", ["-c", shell],
               env: [
                 {"SCRIPT", @script},
                 {"CLI", cli},
                 {"STATE", state},
                 {"WORKTREE", worktree},
                 {"CAPTURE", capture}
               ],
               stderr_to_stdout: true
             )

    argv = String.split(String.trim(out), "\n")

    assert [
             "node",
             "bin/zcode.js",
             "--prompt",
             prompt,
             "--cwd",
             cwd,
             "--json",
             "--mode",
             "yolo"
           ] = argv

    assert prompt =~
             ~r/^\/xaas Call claim_next with provider_worker_id exactly "zcode-dispatch-[^"]+-11111111-\d+" and epoch_id exactly "11111111-1111-1111-1111-111111111111"; do not use any other values\.$/

    assert cwd == realpath(worktree)
  end

  defp realpath(dir) do
    {out, 0} = System.cmd("/bin/pwd", ["-P"], cd: dir)
    String.trim(out)
  end
end
