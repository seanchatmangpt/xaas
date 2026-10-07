defmodule Xaas.TypedSkipDisciplineChicagoTest do
  @moduledoc """
  Lane W703 (autofde-lab -> xaas gap wave). Court for the environment-blocked
  detection discipline (`afl:Risk_SilentUndercount`'s control in
  /Users/sac/autofde-lab/ontology/airo_risk_description.ttl): an
  environment-blocked suite must be *typed-skipped with a named reason*, never
  silently dropped from the run.

  Two real surfaces, asserted on real files on disk:

    1. every `test.skip(` in `e2e/*.cjs` carries a non-empty named reason
       string, and no boolean-only (silent) skip exists;
    2. every conditional `skip:` in the ExUnit tree carries a string (named
       reason or computed condition) -- a bare `skip: true` would silently
       remove a test from every run with zero bits.

  Read-only over the repo tree: no lib code, no network.
  """
  use ExUnit.Case, async: true

  @e2e_dir Path.expand("../../e2e", __DIR__)
  @test_dir Path.expand("..", __DIR__)
  @repo_root Path.expand("../..", __DIR__)

  test "every Playwright test.skip carries a named reason (no silent skips)" do
    specs = Path.wildcard(Path.join(@e2e_dir, "*.spec.cjs"))
    assert length(specs) >= 15, "expected the real e2e spec corpus on disk"

    {total_sites, typed_sites} =
      Enum.reduce(specs, {0, 0}, fn spec, {total, typed} ->
        body = File.read!(spec)
        sites = Regex.scan(~r/test\.skip\(/, body)
        typed_here = Regex.scan(~r/test\.skip\(\s*[^,()]+,\s*"(?:[^"\\]|\\.)*"\s*\)/, body)

        assert length(sites) == length(typed_here),
               "#{spec}: silent or reason-less test.skip found (all skips must carry a named reason string)"

        {total + length(sites), typed + length(typed_here)}
      end)

    assert total_sites >= 8, "the typed-skip convention should be present on this corpus"
    assert total_sites == typed_sites
  end

  test "no bare skip-true in the ExUnit tree (every skip is named or computed)" do
    exs = Path.wildcard(Path.join(@test_dir, "**/*.exs"))
    assert length(exs) >= 100, "expected the real ExUnit tree on disk"

    # This court's own source contains the literal it hunts for; exclude it.
    offenders =
      for path <- exs,
          path != __ENV__.file,
          body = File.read!(path),
          line <- String.split(body, "\n"),
          Regex.match?(~r/skip:\s*true\b/, line),
          do: path

    assert offenders == [],
           "bare `skip: true` found (silent environment-fold): #{inspect(Enum.uniq(offenders))}"
  end
end
