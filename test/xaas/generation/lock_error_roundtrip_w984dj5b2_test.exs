defmodule Xaas.Generation.LockErrorRoundtripW984dj5b2Test do
  @moduledoc """
  W984dj5b2 court leg: the encode-divergence fix from W984dj5's defect
  receipt. A manifest containing an unreadable projection must produce a
  lock that is reproducible across a full disk roundtrip — persist/2's
  error-entry encoding now matches Lock.build/1's canonical no-space form
  (`"error::enoent"`), so:

      build -> persist -> load -> Lock.build == in-memory Lock.build
  """

  use ExUnit.Case, async: true

  alias Xaas.Generation.{HashManifest, Lock, Manifest}

  @tag :w984dj5b2
  test "error entry: in-memory lock is reproducible from the reloaded on-disk manifest" do
    missing = Path.join(System.tmp_dir!(), "xaas_w984dj5b2_missing_#{:erlang.unique_integer([:positive])}")

    manifest = [
      %Manifest.Entry{
        source_path: "s.ex",
        projection_path: missing,
        generator_id: "ggen"
      }
    ]

    hm = HashManifest.build(manifest)
    assert %{^missing => {:error, :enoent}} = hm

    in_memory_lock = Lock.build(hm)

    store =
      Path.join(System.tmp_dir!(), "xaas_w984dj5b2_store_#{:erlang.unique_integer([:positive])}")

    File.write!(store, "")
    ExUnit.Callbacks.on_exit(fn ->
      File.rm(store)
      File.rm(missing)
    end)

    assert :ok = HashManifest.persist(hm, store)
    assert {:ok, loaded} = HashManifest.load(store)

    # canonical no-space encoding on disk, matching Lock.build/1
    # ("error:" <> inspect(:enoent) == "error::enoent")
    assert loaded[missing] == "error::enoent"

    # the fix: reloaded manifest reproduces the in-memory lock exactly
    assert Lock.build(loaded) == in_memory_lock
    assert Lock.verify(loaded, in_memory_lock) == :match
  end

  @tag :w984dj5b2
  test "mixed manifest (digest + error entries) roundtrips to the same lock" do
    real =
      Path.join(System.tmp_dir!(), "xaas_w984dj5b2_real_#{:erlang.unique_integer([:positive])}")

    File.write!(real, "real projection content\n")
    missing = Path.join(System.tmp_dir!(), "xaas_w984dj5b2_gone_#{:erlang.unique_integer([:positive])}")

    manifest = [
      %Manifest.Entry{source_path: "a.ex", projection_path: real, generator_id: "ggen"},
      %Manifest.Entry{source_path: "b.ex", projection_path: missing, generator_id: "ggen"}
    ]

    hm = HashManifest.build(manifest)
    in_memory_lock = Lock.build(hm)

    store =
      Path.join(System.tmp_dir!(), "xaas_w984dj5b2_mixed_#{:erlang.unique_integer([:positive])}")

    File.write!(store, "")
    ExUnit.Callbacks.on_exit(fn ->
      File.rm(store)
      File.rm(real)
      File.rm(missing)
    end)

    assert :ok = HashManifest.persist(hm, store)
    assert {:ok, loaded} = HashManifest.load(store)
    assert Lock.build(loaded) == in_memory_lock
  end
end
