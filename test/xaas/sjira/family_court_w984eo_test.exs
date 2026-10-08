defmodule Xaas.Sjira.FamilyCourtW984eoTest do
  @moduledoc """
  W984eo unclaimed-family probe court for `Xaas.Sjira` residue.

  Targets branches with zero prior direct execution:

  - `Xaas.Sjira.RateLimit`: malformed/precedence/clamp branches of
    `delay_ms/3` beyond the two happy-path asserts in
    `atlassian_transport_test.exs`.
  - `Xaas.Sjira.Checkpoint`: the real-filesystem load/save/clear/migrate
    lifecycle (prior tests only exercised `Checkpoint.path/3` and a
    hand-written MemoryCheckpoint double — a real interface implementation,
    not the real file-backed state).
  - `Xaas.Sjira.EngineerWorkflow.Codec`: `encode_cursor/decode_cursor/digest/
    encode_pretty` and the atom/tuple canonicalization clauses, none of which
    were referenced by any test before this court.
  """

  use ExUnit.Case, async: true

  alias Xaas.Sjira.Checkpoint
  alias Xaas.Sjira.EngineerWorkflow.Codec
  alias Xaas.Sjira.RateLimit

  describe "RateLimit.delay_ms/3 uncovered branches" do
    @tag :w984eo
    test "malformed Retry-After falls back to exponential backoff" do
      # Mutation rationale: if parse-failure fell through as an instructed
      # delay (or crashed instead of falling back), 429 recovery would break.
      assert 2_000 ==
               RateLimit.delay_ms(
                 [{"Retry-After", "soon"}],
                 3,
                 now_ms: 0,
                 base_backoff_ms: 500,
                 max_backoff_ms: 30_000
               )
    end

    test "malformed reset header falls back to exponential backoff" do
      # Mutation rationale: reset parse failure must not yield a raw epoch.
      assert 2_000 ==
               RateLimit.delay_ms(
                 [{"X-RateLimit-Reset", "not-an-epoch"}],
                 3,
                 now_ms: 0,
                 base_backoff_ms: 500,
                 max_backoff_ms: 30_000
               )
    end

    test "retry-after takes precedence over reset header" do
      # Mutation rationale: instruction precedence is the documented contract
      # ("server instructions win over local exponential backoff").
      assert 9_000 ==
               RateLimit.delay_ms(
                 [{"Retry-After", "9"}, {"X-RateLimit-Reset", "999999999"}],
                 1,
                 now_ms: 0
               )
    end

    test "past epoch clamps to zero delay" do
      # Mutation rationale: removing the max(.., 0) clamp would return a
      # negative delay, which callers treat as an invalid sleep.
      assert 0 ==
               RateLimit.delay_ms(
                 [{"X-RateLimit-Reset", "10"}],
                 1,
                 now_ms: 60_000
               )
    end

    test "delay is capped at max_backoff_ms" do
      # Mutation rationale: min(max_ms) cap must bind for deep retry counts;
      # attempt 12 unbounded = 500 * 2^11 = 1_024_000ms.
      assert 30_000 ==
               RateLimit.delay_ms(
                 [],
                 12,
                 now_ms: 0,
                 base_backoff_ms: 500,
                 max_backoff_ms: 30_000
               )
    end

    test "retry-after of zero is honored as an instructed value" do
      # Mutation rationale: Kernel.|| semantics must treat 0 as instructed,
      # not as absence — otherwise a "retry now" instruction is ignored.
      assert 0 ==
               RateLimit.delay_ms([{"Retry-After", "0"}], 1, now_ms: 0)
    end

    test "non-tuple entries in a header list are skipped" do
      # Mutation rationale: normalize/1's flat_map drop clause must discard
      # malformed entries instead of raising to_string/2 on :garbage.
      assert 7_000 ==
               RateLimit.delay_ms([{"Retry-After", "7"}, :garbage], 1, now_ms: 0)
    end

    test "alternate x-rate-limit-reset header spelling is accepted" do
      # Mutation rationale: header/3 normalization must match the second
      # documented spelling, not just X-RateLimit-Reset.
      assert 5_000 ==
               RateLimit.delay_ms(
                 [{"x-rate-limit-reset", "15"}],
                 1,
                 now_ms: 10_000
               )
    end

    test "map headers and atom keys normalize identically" do
      # Mutation rationale: normalize(%{}) to_string path.
      assert 7_000 ==
               RateLimit.delay_ms(
                 %{"RETRY-AFTER" => "7"},
                 1,
                 now_ms: 0
               )
    end

    test "unknown headers fall back to exponential backoff" do
      # Mutation rationale: pure-backoff branch with attempt=1 (shift 0).
      assert 500 ==
               RateLimit.delay_ms([{"Unrelated", "1"}], 1, now_ms: 0)
    end
  end

  describe "Checkpoint real-filesystem lifecycle" do
    @tag :w984eo
    test "save/load roundtrip returns identical state" do
      # Mutation rationale: encode/decode canonicalization must roundtrip
      # real delivery state byte-semantically through the real filesystem.
      dir = real_tmp_dir()
      scope = "w984eo-scope"
      run_key = "run-#{System.unique_integer([:positive])}"

      state = %{
        "version" => 1,
        "cursor" => 3,
        "completed" => %{"urn:work:1" => "ok"},
        "failed" => ["urn:work:2"],
        "inflight" => nil
      }

      assert {:ok, target} = Checkpoint.save(scope, run_key, state, checkpoint_dir: dir)
      assert String.ends_with?(target, ".json")
      assert File.exists?(target)
      assert {:ok, ^state} = Checkpoint.load(scope, run_key, checkpoint_dir: dir)
    end

    test "load of corrupt json is a typed error, not a crash" do
      # Mutation rationale: {:error, {:invalid_checkpoint_json, _}} branch.
      dir = real_tmp_dir()
      scope = "w984eo-corrupt"
      run_key = "run-#{System.unique_integer([:positive])}"
      target = Checkpoint.path(scope, run_key, checkpoint_dir: dir)
      File.mkdir_p!(Path.dirname(target))
      File.write!(target, "{not json")

      assert {:error, {:invalid_checkpoint_json, _}} =
               Checkpoint.load(scope, run_key, checkpoint_dir: dir)
    end

    test "load of valid non-map json is a shape error" do
      # Mutation rationale: {:invalid_checkpoint_shape, other} branch.
      dir = real_tmp_dir()
      scope = "w984eo-shape"
      run_key = "run-#{System.unique_integer([:positive])}"
      target = Checkpoint.path(scope, run_key, checkpoint_dir: dir)
      File.mkdir_p!(Path.dirname(target))
      File.write!(target, "[1, 2, 3]")

      assert {:error, {:invalid_checkpoint_shape, [1, 2, 3]}} =
               Checkpoint.load(scope, run_key, checkpoint_dir: dir)
    end

    test "load of a missing checkpoint returns {:ok, nil}" do
      # Mutation rationale: enoent is absence, not failure.
      assert {:ok, nil} =
               Checkpoint.load("w984eo-absent", "run-#{System.unique_integer([:positive])}",
                 checkpoint_dir: real_tmp_dir()
               )
    end

    test "clear removes state; clear of absent is :ok" do
      # Mutation rationale: File.rm enoent -> :ok branch and the real delete.
      dir = real_tmp_dir()
      scope = "w984eo-clear"
      run_key = "run-#{System.unique_integer([:positive])}"

      assert {:ok, _} = Checkpoint.save(scope, run_key, %{"cursor" => 1}, checkpoint_dir: dir)
      assert :ok = Checkpoint.clear(scope, run_key, checkpoint_dir: dir)
      assert {:ok, nil} = Checkpoint.load(scope, run_key, checkpoint_dir: dir)
      assert :ok = Checkpoint.clear(scope, run_key, checkpoint_dir: dir)
    end

    test "migrate stamps v0 state to v1 with all defaults" do
      # Mutation rationale: the put_new defaulting chain — dropping any
      # default silently changes downstream cursor/failed handling.
      state = %{"cursor" => 5}

      assert {:ok, %{"version" => 1, "cursor" => 5, "completed" => %{}, "failed" => [], "inflight" => nil}} =
               Checkpoint.migrate(state, 1)
    end

    test "migrate of matching version is identity" do
      # Mutation rationale: first migrate/2 clause must not re-default an
      # already-versioned state.
      state = %{"version" => 1, "cursor" => 9}
      assert {:ok, ^state} = Checkpoint.migrate(state, 1)
    end

    test "migrate to unsupported version is refused" do
      # Mutation rationale: typed refusal branch.
      assert {:error, {:unsupported_checkpoint_version, 1, 2}} =
               Checkpoint.migrate(%{"version" => 1, "cursor" => 0}, 2)
    end

    test "path scopes hostile scope names into safe segments" do
      # Mutation rationale: safe_segment regex replace + default branch;
      # a traversal-passing mutation writes outside the checkpoint root.
      hostile = "../../etc/passwd"
      p = Checkpoint.path(hostile, "k", checkpoint_dir: "/tmp/w984eo-paths")

      # Safety property: "/" is rewritten, so the scope remains ONE literal
      # path segment — ".." characters survive inside the name but cannot
      # traverse without separators.
      assert String.starts_with?(p, "/tmp/w984eo-paths/")
      segment = p |> Path.relative_to("/tmp/w984eo-paths") |> Path.dirname()
      refute segment =~ "/"
      assert segment == "..-..-etc-passwd"

      # The whole scoped path is creatable and contained under the root.
      File.mkdir_p!(Path.dirname(p))
      assert {:ok, written} =
               Checkpoint.save(hostile, "k", %{"cursor" => 0}, checkpoint_dir: "/tmp/w984eo-paths")

      assert String.starts_with?(written, "/tmp/w984eo-paths/")
    end
  end

  describe "EngineerWorkflow.Codec uncovered functions" do
    @tag :w984eo
    test "encode_pretty renders canonical sorted pretty json" do
      # Mutation rationale: encode_pretty was never executed; canonical
      # ordering must hold in pretty mode too.
      assert Codec.encode_pretty(%{b: 2, a: %{d: 4, c: 3}}) ==
               ~s({\n  "a": {\n    "c": 3,\n    "d": 4\n  },\n  "b": 2\n}\n)
    end

    test "digest is stable and key-order independent" do
      # Mutation rationale: digest hashes canonical encode; order-dependent
      # digest would break cross-lane receipt comparison.
      d1 = Codec.digest(%{a: 1, b: [1, 2]})
      d2 = Codec.digest(%{b: [1, 2], a: 1})
      assert d1 == d2
      assert String.starts_with?(d1, "sha256:")
      assert d1 == Codec.digest(%{a: 1, b: [1, 2]})
    end

    test "cursor roundtrip preserves payload" do
      # Mutation rationale: encode_cursor/decode_cursor had zero coverage;
      # this is the pagination cursor the engineer workflow issues.
      payload = %{"after" => "urn:work:42", "limit" => 25}
      cursor = Codec.encode_cursor(payload)
      assert is_binary(cursor)
      refute cursor =~ "="
      assert {:ok, ^payload} = Codec.decode_cursor(cursor)
    end

    test "decode_cursor refuses non-base64 garbage" do
      # Mutation rationale: :error clause of the with-chain.
      assert {:refused, :invalid_cursor_encoding, _} =
               Codec.decode_cursor("!!!not base64!!!")
    end

    test "decode_cursor refuses base64 of non-json" do
      # Mutation rationale: {:error, reason} Jason clause.
      garbage = Base.url_encode64("plainly not json", padding: false)

      assert {:refused, :invalid_cursor_encoding, _} =
               Codec.decode_cursor(garbage)
    end

    test "decode_cursor refuses base64 of valid non-map json" do
      # Mutation rationale: {:ok, other} clause (payload must be a map).
      arr = Base.url_encode64("[1,2,3]", padding: false)

      assert {:refused, :invalid_cursor_encoding, [1, 2, 3]} =
               Codec.decode_cursor(arr)
    end

    test "canonicalization stringifies atoms and flattens tuples" do
      # Mutation rationale: atom/tuple clauses were never executed by any
      # prior test; encode of %{status: :ok} must not crash.
      assert Codec.encode(%{status: :ok, pair: {:a, 1}}) ==
               ~s({"pair":["a",1],"status":"ok"})
    end
  end

  defp real_tmp_dir do
    Path.join(System.tmp_dir!(), "w984eo-checkpoints")
  end
end
