defmodule Xaas.Chicago.RenderTaskTest do
  @moduledoc """
  Render task tests (resolution R4 scope 4/5).

  The real renderer (ggen sync over the marketplace pack) is L2's surface and
  is NOT exercised here — every success-path test injects a render_fn. The
  typed refusal paths are exercised against the live repository state, where
  `priv/chicago/` and (during wave 2) the pack directory do not exist. No test
  may pass because a render landed underneath it: the absence path is asserted
  explicitly, and if the pack or priv/chicago appears the test says so.
  """

  use ExUnit.Case, async: true

  alias Mix.Tasks.Xaas.Chicago.Render
  alias Xaas.Chicago.{Projection, Subject}

  @machine_fixture Path.expand("fixtures/chicago.machine.fixture.json", __DIR__)
  @executive_fixture Path.expand("fixtures/chicago.executive.fixture.json", __DIR__)
  @artifacts ~w(chicago.machine.json chicago.verification.json chicago.executive.json chicago.replay.json)

  defp tmp_dir(prefix) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}-#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  defp fake_pack do
    pack = tmp_dir("chicago-fake-pack")
    File.write!(Path.join(pack, "ggen.toml"), "# fake pack manifest (test)\n")
    pack
  end

  defp copy_fixture_render_inner do
    machine = File.read!(@machine_fixture)
    executive = File.read!(@executive_fixture)

    fn _pack, out_dir ->
      File.write!(Path.join(out_dir, "chicago.machine.json"), machine)
      File.write!(Path.join(out_dir, "chicago.executive.json"), executive)

      verification =
        String.replace(
          machine,
          "\"projectionType\": \"machine\"",
          "\"projectionType\": \"verification\""
        )

      replay =
        String.replace(
          machine,
          "\"projectionType\": \"machine\"",
          "\"projectionType\": \"replay\""
        )

      File.write!(Path.join(out_dir, "chicago.verification.json"), verification)
      File.write!(Path.join(out_dir, "chicago.replay.json"), replay)

      :ok
    end
  end

  describe "typed refusals against live repository state" do
    test "absent pack directory refuses :chicago_renderer_absent" do
      absent = Path.join(System.tmp_dir!(), "no-such-pack-#{:erlang.unique_integer([:positive])}")

      assert {:refused, {:chicago_renderer_absent, ^absent}} =
               Render.render(absent, render_fn: fn _, _ -> :ok end)
    end

    test "pack without ggen.toml refuses :chicago_renderer_absent" do
      bare = tmp_dir("chicago-bare-pack")

      assert {:refused, {:chicago_renderer_absent, {:no_manifest, ^bare}}} =
               Render.render(bare, render_fn: fn _, _ -> :ok end)
    end

    test "default pack absent in this environment -> run/1 exits nonzero with a typed message" do
      pack = Render.default_pack_dir()

      if File.dir?(pack) and File.exists?(Path.join(pack, "ggen.toml")) do
        # The pack landed (L2/integration): the default-path absence refusal
        # cannot fire here and running the REAL render in a lane test is
        # forbidden (shared tree). Say so instead of faking a verdict.
        :pack_present_real_render_not_exercised_in_lane
      else
        assert_raise(Mix.Error, ~r/REFUSED_CHICAGO_RENDER/, fn -> Render.run([]) end)
      end
    end

    test "failing render_fn refuses :chicago_render_failed" do
      assert {:refused, {:chicago_render_failed, "boom"}} =
               Render.render(fake_pack(), render_fn: fn _, _ -> {:error, "boom"} end)
    end

    test "render missing artifacts refuses :chicago_render_failed" do
      partial = fn _, out_dir ->
        File.write!(Path.join(out_dir, "chicago.machine.json"), File.read!(@machine_fixture))
        :ok
      end

      assert {:refused, {:chicago_render_failed, {:missing_artifacts, missing}}} =
               Render.render(fake_pack(), render_fn: partial)

      assert "chicago.executive.json" in missing
    end

    test "unstable double render refuses :chicago_render_unstable" do
      counter = :counters.new(1, [:atomics])
      stable_machine = File.read!(@machine_fixture)
      executive = File.read!(@executive_fixture)

      flaky = fn _pack, out_dir ->
        n = :counters.get(counter, 1)
        :counters.add(counter, 1, 1)

        # ONLY chicago.machine.json varies between the two renders
        unstable =
          String.replace(
            stable_machine,
            "\"baseSha\": \"fixture-base-not-a-commit\"",
            "\"baseSha\": \"unstable-#{n}\""
          )

        File.write!(Path.join(out_dir, "chicago.machine.json"), unstable)
        File.write!(Path.join(out_dir, "chicago.executive.json"), executive)
        File.write!(Path.join(out_dir, "chicago.verification.json"), stable_machine)
        File.write!(Path.join(out_dir, "chicago.replay.json"), stable_machine)

        :ok
      end

      assert {:refused, {:chicago_render_unstable, differing}} =
               Render.render(fake_pack(),
                 render_fn: flaky,
                 dest_dir: tmp_dir("chicago-dest-unstable")
               )

      assert differing == ["chicago.machine.json"]
    end
  end

  describe "byte-stable double render copies and validates" do
    test "stable render copies artifacts with digests and passes consumer validation" do
      dest = tmp_dir("chicago-dest")
      render_fn = copy_fixture_render_inner()

      assert {:ok, rendered} = Render.render(fake_pack(), render_fn: render_fn, dest_dir: dest)

      assert Enum.map(rendered, &elem(&1, 0)) |> Enum.sort() == Enum.sort(@artifacts)

      machine_path = Path.join(dest, "chicago.machine.json")
      {name, digest} = Enum.find(rendered, fn {n, _} -> n == "chicago.machine.json" end)
      assert name == "chicago.machine.json"
      expected = :crypto.hash(:sha256, File.read!(machine_path)) |> Base.encode16(case: :lower)
      assert digest == expected

      # the copied machine projection passes the consumer validator directly
      assert {:ok, machine} = Projection.load(:machine, machine_path)
      assert Subject.matches?(machine["subject"])
    end

    test "stable render with invalid projection content refuses :chicago_render_invalid_projection" do
      dest = tmp_dir("chicago-dest-invalid")

      broken =
        String.replace(
          File.read!(@machine_fixture),
          "\"generated\": true",
          "\"generated\": false"
        )

      render_fn = fn _pack, out_dir ->
        File.write!(Path.join(out_dir, "chicago.machine.json"), broken)
        File.write!(Path.join(out_dir, "chicago.executive.json"), File.read!(@executive_fixture))
        File.write!(Path.join(out_dir, "chicago.verification.json"), broken)
        File.write!(Path.join(out_dir, "chicago.replay.json"), broken)
        :ok
      end

      assert {:refused, {:chicago_render_invalid_projection, {_path, :generated_not_true}}} =
               Render.render(fake_pack(), render_fn: render_fn, dest_dir: dest)
    end
  end
end
