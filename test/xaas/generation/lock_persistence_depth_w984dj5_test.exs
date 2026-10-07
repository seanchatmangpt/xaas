defmodule Xaas.Generation.LockPersistenceDepthW984dj5Test do
  @moduledoc """
  W984dj5 depth court: `Xaas.Generation.Lock` + the `HashManifest`
  persist/load disk roundtrip.

  Census finding (this lane): `HashManifest.persist/2` and `load/1` had
  zero test references, and `Lock` was only covered over in-memory maps.
  This court exercises the real disk chain: build a real file, hash it,
  persist the hash manifest to disk, load it back, and check the lock
  invariants against real on-disk tamper.

  Chicago-style: real temp files, real SHA-256, real JSON on disk. No mocks.
  """

  use ExUnit.Case, async: true

  alias Xaas.Generation.{HashManifest, Lock, Manifest}

  defp tmp_path(name) do
    Path.join(
      System.tmp_dir!(),
      "xaas_w984dj5_#{name}_#{System.system_time(:millisecond)}_#{:erlang.unique_integer([:positive])}"
    )
  end

  defp write_tmp(name, content) do
    path = tmp_path(name)
    File.write!(path, content)
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)
    path
  end

  defp entry(source, projection) do
    %Manifest.Entry{
      source_path: source,
      projection_path: projection,
      generator_id: "ggen"
    }
  end

  defp real_hash_manifest do
    p1 = write_tmp("proj_a", "generated body A v1\n")
    p2 = write_tmp("proj_b", "generated body B v1\n")
    HashManifest.build([%Manifest.Entry{source_path: "s/a.ex", projection_path: p1, generator_id: "ggen"},
                       %Manifest.Entry{source_path: "s/b.ex", projection_path: p2, generator_id: "ggen"}])
  end

  @tag :w984dj5
  test "lock digest is insertion-order-insensitive over equal content (the sort is load-bearing)" do
    p1 = write_tmp("ord_a", "alpha\n")
    p2 = write_tmp("ord_b", "beta\n")
    hm_forward = %{p1 => "aa" |> String.duplicate(32), p2 => "bb" |> String.duplicate(32)}
    hm_reversed = %{p2 => "bb" |> String.duplicate(32), p1 => "aa" |> String.duplicate(32)}

    assert Lock.build(hm_forward) == Lock.build(hm_reversed)
  end

  @tag :w984dj5
  test "persist -> load roundtrip through real disk reproduces the lock (verify :match)" do
    hm = real_hash_manifest()
    expected_lock = Lock.build(hm)
    store = write_tmp("store", "")

    assert :ok = HashManifest.persist(hm, store)
    assert {:ok, loaded} = HashManifest.load(store)

    # loaded digests equal the in-memory digests, entry for entry
    assert loaded == Map.new(hm, fn {k, v} -> {k, v} end)
    assert Lock.verify(loaded, expected_lock) == :match
  end

  @tag :w984dj5
  test "a real on-disk tamper after persist is detected as :mismatch after reload" do
    p = write_tmp("tamper_target", "v1\n")
    hm = HashManifest.build([entry("s.ex", p)])
    store = write_tmp("store", "")
    :ok = HashManifest.persist(hm, store)

    # mutate the real file on disk, recompute, reload, verify
    File.write!(p, "v2 tampered\n")
    hm2 = HashManifest.build([entry("s.ex", p)])
    assert {:ok, loaded} = HashManifest.load(store)
    assert Lock.verify(hm2, Lock.build(loaded)) == :mismatch
  end

  @tag :w984dj5
  test "lock distinguishes an error entry from a digest entry, and persist encodes the error without hiding it" do
    missing = tmp_path("missing")
    hm = HashManifest.build([entry("s.ex", missing)])

    assert %{^missing => {:error, :enoent}} = hm
    lock_with_error = Lock.build(hm)

    # a same-path digest entry must NOT produce the same lock
    hm_digest = %{missing => String.duplicate("cd", 32)}
    refute Lock.build(hm_digest) == lock_with_error

    # persist encodes the error entry canonically, matching Lock.build's
    # in-memory encoding ("error::enoent", no space) — fixed by W984dj5b2
    store = write_tmp("store", "")
    assert :ok = HashManifest.persist(hm, store)
    assert {:ok, loaded} = HashManifest.load(store)
    assert loaded[missing] == "error::enoent"

    # the fix closes the disclosed asymmetry: a lock computed in-memory over an
    # error entry IS reproducible from the reloaded on-disk manifest.
    # (Historical note: persist used to write "error: :enoent" with a space,
    # breaking the roundtrip — witnessed by W984dj5's receipt, fixed here.)
    assert Lock.build(loaded) == lock_with_error
  end

  @tag :w984dj5
  test "empty-manifest lock is well-defined and differs from every nonempty lock; load failure is typed" do
    empty_lock = Lock.build(%{})
    assert is_binary(empty_lock) and byte_size(empty_lock) == 64

    hm = real_hash_manifest()
    refute Lock.build(hm) == empty_lock
    assert Lock.verify(%{}, empty_lock) == :match
    assert Lock.verify(hm, empty_lock) == :mismatch

    # typed load failures: missing store and malformed JSON, never raise
    assert {:error, :enoent} = HashManifest.load(tmp_path("never_written"))
    bad = write_tmp("bad_store", "{not json")
    assert {:error, %Jason.DecodeError{}} = HashManifest.load(bad)
  end
end
