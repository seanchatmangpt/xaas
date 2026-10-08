defmodule Xaas.Deepening.Art133eLiveToolchainPinTest do
  @moduledoc """
  Lane W984al — evidenced-line deepening wave 5, corpus line **13.3.e**
  (Art. 13(3)(b)-(e) instruction-for-use content, classified in the
  corpus evidence map as "resources/lifetime/maintenance: pinned
  toolchain + CHANGELOG/VERSION record the resource and maintenance
  surface", evidence "docs+W322").

  Prior coverage of the toolchain maintenance surface is FILE-ONLY:
  `toolchain_court_test.exs` (W704) asserts the pins written in
  `.tool-versions` and the CI extraction via `scripts/versions.sh` —
  it never executes the running BEAM. The uncovered property is
  LIVENESS: the BEAM actually executing this tree matches the pinned
  maintenance surface. This is a real, witnessed failure class on this
  fleet (auto-memory: "Homebrew elixir shadows asdf" — a plain `mix`
  can run 1.19.5 under the repo root while the pin says 1.20.2).

  Mutation rationale: any drift between the documented pin and the live
  runtime — an unpinned/shadowed toolchain, a stale pin after a
  toolchain bump, an elixir-build/OTP pairing drift — fails the live-pin
  courts while `toolchain_court_test.exs`'s file-and-CI courts still
  pass (they never compare against the executing VM).

  Chicago discipline: real file reads of `.tool-versions`, real runtime
  introspection (`System.version/0`, `:erlang.system_info(:otp_release)`,
  `:runtime_tools` app check), assertions on returned final state.
  No mocks.
  """

  use ExUnit.Case, async: true

  # 13.3.e is an evidenced corpus line (docs+W322 evidence entry) —
  # eu_ai_act census.
  @moduletag :eu_ai_act

  @tool_versions_path ".tool-versions"

  defp pinned_version(tool) do
    @tool_versions_path
    |> File.read!()
    |> String.split("\n")
    # versions.sh convention: last pin wins, blank lines skipped.
    |> Enum.reduce(nil, fn line, acc ->
      case String.split(String.trim(line), " ") do
        [^tool, ver] -> ver
        _ -> acc
      end
    end)
    |> case do
      nil -> flunk("no #{tool} pin in #{@tool_versions_path}")
      ver -> ver
    end
  end

  test "court 1 — the BEAM executing this tree matches the pinned elixir build (live pin, not file pin)" do
    pin = pinned_version("elixir")
    # asdf ref format: "<version>-otp-<major>"; the executable's Elixir
    # version is the portion before the -otp suffix.
    expected_elixir =
      pin
      |> String.split("-otp-")
      |> List.first()
      |> then(&(&1 || pin))

    live = System.version()

    assert live == expected_elixir,
           "live Elixir #{live} != pinned #{pin} — unpinned/shadowed " <>
             "toolchain executing the tree (maintenance-surface drift, " <>
             "Art 13(3)(e) court)"
  end

  test "court 2 — the live OTP release matches the pinned erlang line and the elixir/otp pairing is coherent" do
    erlang_pin = pinned_version("erlang")
    elixir_pin = pinned_version("elixir")

    live_otp = List.to_string(:erlang.system_info(:otp_release))

    # :otp_release is the major release line ("28"); the pin carries the
    # full maintenance version ("28.5.0.2"). The live line must be the
    # pin's line.
    assert live_otp == erlang_pin || String.starts_with?(erlang_pin, live_otp <> "."),
           "live OTP #{live_otp} not on the pinned erlang line #{erlang_pin}"

    # Pairing coherence: the elixir pin declares the OTP line it was
    # built against; the live VM must be that line (catches running an
    # elixir-1.20/otp-28 build on an otp-27 VM or vice versa).
    case String.split(elixir_pin, "-otp-") do
      [_, declared_otp] ->
        assert live_otp == declared_otp,
               "elixir pin #{elixir_pin} declares otp-#{declared_otp} " <>
                 "but the live VM is otp-#{live_otp}"

      _ ->
        flunk("elixir pin #{elixir_pin} carries no -otp- build suffix")
    end
  end

  test "court 3 — the pinned runtime actually executes the corpus gate family (maintenance surface is live, not inert)" do
    # Execute a real gate under the pinned runtime and consume its typed
    # verdict — the resource declared for the system's lifetime is the
    # one actually computing.
    assert {:ok, :ADMITTED, %{completeness: c}} =
             Xaas.Semantics.DatasetAdmission.admit(
               for(k <- 1..10, s <- [0, 1],
                 do: %{
                   features: %{x: k * 1.0},
                   label: :ok,
                   sensitive: s
                 }),
               seed: 7,
               eta: 0.5,
               epsilon_bias: 0.2,
               required_fields: [:x]
             )

    assert c == 1.0
  end
end
