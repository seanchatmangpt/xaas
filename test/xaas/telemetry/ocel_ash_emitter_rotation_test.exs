defmodule Xaas.Telemetry.OcelAshEmitterRotationTest do
  @moduledoc """
  Chicago-school tests for `Xaas.Telemetry.OcelAshEmitter`'s rotation law
  (the V9 telemetry-hygiene change): the OCEL ndjson egress is size-capped
  instead of appended to without bound (the pre-cap test build reached
  352MB / 844,698 lines; the dev build 5.6MB and growing).

  No mocks anywhere: the law is exercised against REAL files in a REAL
  sandbox directory (`System.tmp_dir!/1`-scoped, unique per test, removed
  on exit), and the end-to-end test drives the module's REAL
  `handle_event/4` (the exact function `:telemetry` invokes) through the
  REAL append path against the REAL test-env log
  (`_build/test/lib/xaas/priv/ocel/ash-actions.ndjson` -- a different
  file from the running dev server's `_build/dev/...` log, so the live
  egress is never touched). Over-cap there is reached by pre-padding the
  file, not by fabricating thousands of Ash actions.

  The production defaults are pinned by an explicit assertion
  (`rotation_defaults/0` == 10 MiB cap, 2 rotated files): changing them
  must be a conscious decision, not drift.
  """

  use ExUnit.Case, async: false

  alias Xaas.Telemetry.OcelAshEmitter
  alias Xaas.Ultracode.Ocel.Validator

  @prod_log OcelAshEmitter.log_path()

  setup ctx do
    sandbox =
      Path.join(System.tmp_dir!(), "ocel-rotation-test-#{ctx.test}-#{System.unique_integer()}")

    File.mkdir_p!(sandbox)
    on_exit(fn -> File.rm_rf(sandbox) end)

    # The end-to-end test appends to the shared test-env log; leave it
    # truncated and rotated-sibling-free for the rest of the suite.
    on_exit(fn ->
      File.rm(@prod_log <> ".1")
      File.rm(@prod_log <> ".2")
      File.write(@prod_log, "")
    end)

    %{sandbox: sandbox}
  end

  defp seed(path, bytes), do: File.write!(path, String.duplicate("a", bytes))

  test "production defaults are a 10 MiB cap with 2 rotated files kept" do
    assert {max_bytes, keep} = OcelAshEmitter.rotation_defaults()
    assert max_bytes == 10 * 1024 * 1024
    assert keep == 2
  end

  test "no-op when the live file is at or under the cap", %{sandbox: sandbox} do
    path = Path.join(sandbox, "log.ndjson")
    seed(path, 20)

    assert :ok = OcelAshEmitter.maybe_rotate(path, max_bytes: 20, keep: 2)

    # At the cap (not over it) there is no rotation -- the cap is an
    # inclusive threshold on the live file, exceeded only past 20 bytes.
    assert File.exists?(path)
    assert File.stat!(path).size == 20
    refute File.exists?(path <> ".1")
  end

  test "rotates the live file to .1 when it exceeds the cap", %{sandbox: sandbox} do
    path = Path.join(sandbox, "log.ndjson")
    seed(path, 21)

    assert :ok = OcelAshEmitter.maybe_rotate(path, max_bytes: 20, keep: 2)

    # The over-cap content survived verbatim as the freshest rotated
    # sibling; the live file is gone (the caller's append recreates it).
    assert File.read!(path <> ".1") == String.duplicate("a", 21)
    refute File.exists?(path)
  end

  test "keeps at most :keep rotated files and deletes the oldest", %{sandbox: sandbox} do
    path = Path.join(sandbox, "log.ndjson")
    # .1 is the freshest previous generation, .2 the oldest, and the live
    # file is over cap: one rotation must shift 1->2, live->1, and drop
    # the old .2 entirely.
    seed(path, 10)
    seed(path <> ".1", 20)
    seed(path <> ".2", 30)

    assert :ok = OcelAshEmitter.maybe_rotate(path, max_bytes: 5, keep: 2)

    assert File.read!(path <> ".1") == String.duplicate("a", 10)
    assert File.read!(path <> ".2") == String.duplicate("a", 20)
    refute File.exists?(path)
    assert File.exists?(path <> ".1") and not File.exists?(path <> ".3")
  end

  test "a missing live file is a safe no-op", %{sandbox: sandbox} do
    path = Path.join(sandbox, "absent.ndjson")

    assert :ok = OcelAshEmitter.maybe_rotate(path, max_bytes: 1, keep: 2)

    refute File.exists?(path)
    refute File.exists?(path <> ".1")
  end

  test "real handle_event/4 append path rotates the test-env log past the production cap" do
    {max_bytes, _keep} = OcelAshEmitter.rotation_defaults()
    File.mkdir_p!(Path.dirname(@prod_log))
    # Exactly at the cap must NOT rotate (inclusive threshold, asserted
    # above on sandbox files); go one byte over for the real egress run.
    File.write!(@prod_log, String.duplicate("a", max_bytes + 1))

    # The REAL function the :telemetry handlers invoke -- full real path:
    # build_ocel_event (real Ash introspection of the real resource) ->
    # maybe_rotate -> append -> OTel enrichment -> forward.
    :ok =
      OcelAshEmitter.handle_event(
        [:ash, :library, :create, :stop],
        %{duration: 1_000_000},
        %{resource: Xaas.Library.Book, action: :create, domain: Xaas.Library},
        nil
      )

    assert File.stat!(@prod_log <> ".1").size == max_bytes + 1

    # The live log now holds exactly this test's one real OCEL event:
    # a complete, individually-conformant OCEL 2.0 document (the v2
    # reshape law) whose single event carries the real facts.
    [line] =
      @prod_log
      |> File.read!()
      |> String.split("\n", trim: true)

    line_document = Jason.decode!(line)
    assert {:ok, _report} = Validator.validate(line_document)

    # Real short_name of Xaas.Library.Book is "book" (observed, not
    # assumed from the module name's case).
    assert [event] = line_document["ocel:events"]
    assert event["type"] == "book.create"
    assert event["attributes"]["outcome"] == "ok"
    assert byte_size(line) + 1 < max_bytes
  end
end
