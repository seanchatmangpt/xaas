defmodule Xaas.Generation.HashManifestCourtW984hwTest do
  @moduledoc """
  Lane W984hw unclaimed-family probe court on `lib/xaas/generation/hash_manifest.ex`.

  Census: the family is largely covered — compute_hash/verify happy + mismatch
  paths (generation_test.exs), build with mixed digest/error entries
  (generation_test.exs:85-88), the 02902f5c canonical `"error:" <> inspect(reason)`
  form pinned via :enoent roundtrip (lock_error_roundtrip_w984dj5b2_test.exs:47),
  load/1 failure paths (family_court_w984hj_test.exs:109-121), and persist/load
  roundtrip reproducibility (lock_persistence_depth_w984dj5_test.exs). Those
  branches are typed COVERED here; no filler re-tests.

  Genuinely unexercised before this court:

  1. Error-reason encode for a non-:enoent reason (`:eisdir` — projection path
     is a real directory). The existing canonical-form pin only covers :enoent;
     a regression to a space-separated form on :eisdir
     entries would survive the prior suite.
  2. `HashManifest.build/1` order-independence over the Manifest entry list
     (Lock.build determinism was tested; HashManifest.build itself was not).
  3. `verify/3` error tunnel: an unreadable path flows {:error, reason} through
     verify/2 unchanged (prior tests only hit match/mismatch).
  """

  use ExUnit.Case, async: true

  alias Xaas.Generation.{HashManifest, Manifest}

  defp tmp(name),
    do: Path.join(System.tmp_dir!(), "w984hw-#{name}-#{System.unique_integer([:positive])}")

  describe "error-reason encode (02902f5c canonical form)" do
    @tag :w984hw
    test ":eisdir entries persist in canonical no-space form and load back as \"error::eisdir\"" do
      # Mutation rationale: reverting 02902f5c to "error: #{inspect(reason)}"
      # must fail THIS test for :eisdir — the prior pin (:enoent only) passes
      # on the reverted code, so this closes that encode-divergence gap.
      dir = tmp("projection-dir")
      File.mkdir_p!(dir)
      ExUnit.Callbacks.on_exit(fn -> File.rm_rf(dir) end)

      manifest = [
        %Manifest.Entry{source_path: "s.ex", projection_path: dir, generator_id: "ggen"}
      ]

      hm = HashManifest.build(manifest)
      assert {:error, :eisdir} = Map.fetch!(hm, dir)

      store = tmp("store")
      ExUnit.Callbacks.on_exit(fn -> File.rm(store) end)

      assert :ok = HashManifest.persist(hm, store)
      assert {:ok, loaded} = HashManifest.load(store)
      assert loaded[dir] == "error::eisdir"
    end
  end

  describe "HashManifest.build/1 order-independence" do
    @tag :w984hw
    test "entry list order does not affect the built manifest" do
      # Mutation rationale: replacing Map.new with an order-sensitive reduce
      # (e.g. last-wins duplicates) would survive a single-order suite.
      pa = tmp("a"); pb = tmp("b"); pc = tmp("c")
      File.write!(pa, "alpha"); File.write!(pb, "beta"); File.write!(pc, "gamma")
      ExUnit.Callbacks.on_exit(fn -> Enum.each([pa, pb, pc], &File.rm/1) end)

      entry = fn src, p ->
        %Manifest.Entry{source_path: src, projection_path: p, generator_id: "ggen"}
      end

      m1 = [entry.("a.ex", pa), entry.("b.ex", pb), entry.("c.ex", pc)]
      m2 = Enum.reverse(m1)

      hm1 = HashManifest.build(m1)
      hm2 = HashManifest.build(m2)

      assert hm1 == hm2
      assert map_size(hm1) == 3

      for {p, digest} <- hm1 do
        assert {:ok, ^digest} = HashManifest.compute_hash(p)
      end
    end
  end

  describe "verify/2 error tunnel" do
    @tag :w984hw
    test "unreadable path propagates {:error, :enoent}, never :mismatch" do
      # Mutation rationale: a variant that collapses {:error, reason} into
      # :mismatch would survive the happy/mismatch-only prior suite and
      # misreport infrastructure failure as tampering.
      missing = tmp("never-created")

      assert {:error, :enoent} = HashManifest.verify(missing, String.duplicate("ab", 32))
    end

    @tag :w984hw
    test "directory path propagates {:error, :eisdir} through verify/2" do
      dir = tmp("verify-dir")
      File.mkdir_p!(dir)
      ExUnit.Callbacks.on_exit(fn -> File.rm_rf(dir) end)

      assert {:error, :eisdir} = HashManifest.verify(dir, String.duplicate("cd", 32))
    end
  end
end
