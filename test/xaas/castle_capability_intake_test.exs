defmodule Xaas.CastleCapabilityIntakeTest do
  use ExUnit.Case, async: true

  @path Path.expand("../../semantic/castle-capability-intake.ttl", __DIR__)

  test "projection binds exact ggen-ecosystem source and keeps XaaS as runtime-only crown" do
    graph = File.read!(@path)

    assert graph =~ "50fdfa20c84205a80c6eb94e916cffbedc4b816e"
    assert graph =~ ~s(eco:ownerCapability "RUNTIME_EXISTENCE")
    assert graph =~ ~s(eco:forbidsCapability "CONSEQUENTIAL_ADMISSIBILITY")
    assert graph =~ ~s(eco:projectionStanding "CANDIDATE")
    assert graph =~ ~s(eco:authorityCeiling "CONSTRUCT")
    refute graph =~ ~s(eco:projectionStanding "ALIVE")
    refute graph =~ ~s(eco:authorityCeiling "DO")
  end

  test "all four donor subjects are exact and non-sovereign" do
    graph = File.read!(@path)

    donors = [
      {"seanchatmangpt/zcode-cli", "a568c3c3ee4b377e98fe9db0f37fa90da760734f"},
      {"seanchatmangpt/chatgpt-cloud-elixir", "8efaa40b69c8162d22fe2dc5e59657f8dcff529e"},
      {"seanchatmangpt/dteam", "5c00d757ebc614e1db1dd0d564dd0c34896d57a0"},
      {"seanchatmangpt/mcpp", "5f5ee2175424c63edc6cdc211d3a5289a1c5556f"}
    ]

    for {repo, sha} <- donors do
      assert graph =~ ~s(eco:sourceRepository "#{repo}")
      assert graph =~ ~s(eco:sourceSha "#{sha}")
    end

    assert length(Regex.scan(~r/a eco:ProjectedCapability/, graph)) == 4
    refute graph =~ ~s(eco:runtimePlacement "RUNTIME_CORE")
    refute graph =~ ~s(eco:runtimePlacement "CONSEQUENCE_CROWN")
  end
end
