defmodule Xaas.ToolchainCourtTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Toolchain court for XaaS's asdf pins (W704), mirroring zcode-cli's
  workflow-toolchain-court: a gated surface (here: every consumer of
  `.tool-versions` — setup-beam `version-type: strict`, Docker build args,
  local `asdf install`) must be provably reading the same pinned toolchain.

  zcode-cli refuses a workflow job that can reach a toolchain-gated script
  without the verified toolchain. XaaS's equivalent gate is `scripts/versions.sh`
  (ci_cd.yaml `parse-asdf` -> `ELIXIR_VERSION`/`ERLANG_VERSION` -> Docker
  build args) plus setup-beam strict mode; nothing in-repo asserted that the
  pins themselves are the documented ones or that the extraction survives
  contact with the actual file (e.g. an `elixir 1.20.2-otp-28` pin yields
  `1.20.2` for build args, not the asdf ref).

  Chicago discipline: real file reads, real extraction logic replicated
  exactly from versions.sh (grep | cut -d' ' -f2 | cut -d'-' -f1), asserted
  on final state.
  """

  @tool_versions_path ".tool-versions"
  @versions_sh_path "scripts/versions.sh"
  @ci_workflow_path ".github/workflows/ci_cd.yaml"

  # The documented pins (CLAUDE.md "Toolchain (asdf, pinned in .tool-versions)",
  # observed 2026-09-26) that CI (setup-beam version-type: strict) and every
  # local mix invocation must agree on.
  @elixir_pin "elixir 1.20.2-otp-28"
  @erlang_pin "erlang 28.5.0.2"

  test ".tool-versions carries exactly the documented elixir/erlang pins" do
    assert File.exists?(@tool_versions_path), ".tool-versions is missing"

    lines =
      @tool_versions_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.reject(&(String.trim(&1) == ""))

    assert @elixir_pin in lines, "elixir pin drifted from #{@elixir_pin}: #{inspect(lines)}"
    assert @erlang_pin in lines, "erlang pin drifted from #{@erlang_pin}: #{inspect(lines)}"
  end

  test "versions.sh extraction over the real .tool-versions yields the CI build-arg versions" do
    contents = File.read!(@tool_versions_path)

    # Replicates versions.sh exactly: grep '<tool>' | cut -d' ' -f2 | cut -d'-' -f1
    extract = fn tool ->
      contents
      |> String.split("\n")
      |> Enum.find("", &String.starts_with?(&1, "#{tool} "))
      |> String.split(" ")
      |> Enum.at(1, "")
      |> (&String.split(&1, "-", parts: 2)).()
      |> List.first("")
    end

    assert extract.("elixir") == "1.20.2"
    assert extract.("erlang") == "28.5.0.2"
  end

  test "ci_cd.yaml parses .tool-versions via versions.sh and sets up beam strictly" do
    assert File.exists?(@versions_sh_path), "scripts/versions.sh is missing"
    workflow = File.read!(@ci_workflow_path)

    assert workflow =~ "./scripts/versions.sh",
           "ci_cd.yaml no longer parses .tool-versions via versions.sh"

    # The exact-subject build must not float: strict version-file setup.
    assert workflow =~ "version-type: strict"
  end

  test "versions.sh still emits both versions into GITHUB_ENV" do
    sh = File.read!(@versions_sh_path)

    assert sh =~ "ELIXIR_VERSION="
    assert sh =~ "ERLANG_VERSION="
    assert sh =~ "$GITHUB_ENV"
  end
end
