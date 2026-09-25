# Regenerates (default) or checks (`--check`) the committed current-form SJ-001
# descriptor fixture, test/fixtures/semantic_work/sj-001-descriptor.json, by
# RUNNING its producer -- never by editing it:
#
#   GGEN_IGNITER_DIR=<ggen_igniter checkout> \
#     mix run --no-start scripts/sj001_descriptor_fixture.exs [--check]
#
# The producer is the SJ-001 graph-side projection
# (docs/sjira/v26.9.21/e2e_project.exs: GgenIgniter.SemanticJira.admit_work_order/1
# + the execution descriptor, declaring its digest form) run as ONE `mix run` OS
# process in the graph checkout, over the work order's committed front matter
# (docs/sjira/v26.9.21/001-xaas-semantic-jira-e2e.md), with the same defaults the
# SJ-001 e2e test projects with (ALIAS=sj001, VERIFIER_SUITE=sjira-e2e, no
# checkpoint suffix) -- so the e2e test can assert its fresh projection equals
# this fixture byte for byte.
#
# Toolchain: the graph checkout's .tool-versions pin, elixir AND erlang
# (Xaas.Ultracode.RecipeWorker.toolchain/1), compiling into a private APFS clone
# of the checkout's _build/test so a shared build is never written. The running
# xaas node's Elixir is not used: it is the xaas pin, not the graph's.
#
# Prints one JSON verdict line; exits 0 on success, 1 on a producer refusal or a
# `--check` difference.

alias Xaas.Ultracode.RecipeWorker

check? = "--check" in System.argv()
root = File.cwd!()
ggen = System.get_env("GGEN_IGNITER_DIR") || "/Users/sac/ggen_igniter"
script = Path.join(root, "docs/sjira/v26.9.21/e2e_project.exs")
order = Path.join(root, "docs/sjira/v26.9.21/001-xaas-semantic-jira-e2e.md")
fixture = Path.join(root, "test/fixtures/semantic_work/sj-001-descriptor.json")

verdict = fn map, code ->
  IO.puts(Jason.encode!(map))
  System.halt(code)
end

[_, front_matter] = Regex.run(~r/\A---\n(.*?)\n---/s, File.read!(order))

tmp =
  Path.join(System.tmp_dir!(), "sj001-descriptor-fixture-#{System.unique_integer([:positive])}")

File.mkdir_p!(tmp)
wo = Path.join(tmp, "work-order.json")
out = Path.join(tmp, "descriptor.json")
build = Path.join(tmp, "build")
File.write!(wo, Jason.encode!(Jason.decode!(front_matter)))

source_build = Path.join([ggen, "_build", "test"])

if File.dir?(source_build) do
  {_, 0} = System.cmd("cp", ["-cR", source_build, build], stderr_to_stdout: true)
else
  File.mkdir_p!(build)
end

toolchain =
  case RecipeWorker.toolchain(ggen) do
    {:ok, identity} ->
      identity

    {:error, reason} ->
      File.rm_rf!(tmp)
      verdict.(%{"ok" => false, "stage" => "toolchain", "reason" => inspect(reason)}, 1)
  end

{output, code} =
  System.cmd(toolchain["mix"], ["run", script],
    cd: ggen,
    stderr_to_stdout: true,
    env: [
      {"MIX_ENV", "test"},
      {"MIX_BUILD_PATH", build},
      {"PATH", toolchain["path"] <> ":/usr/bin:/bin"},
      {"ASDF_ELIXIR_VERSION", nil},
      {"ASDF_ERLANG_VERSION", nil},
      {"WO", wo},
      {"OUT", out}
    ]
  )

projection =
  output
  |> String.split("\n", trim: true)
  |> Enum.reverse()
  |> Enum.find_value(fn line ->
    with "{" <> _ <- String.trim(line), {:ok, %{} = decoded} <- Jason.decode(line) do
      decoded
    else
      _ -> nil
    end
  end)

identity = %{
  "ggen_igniter_dir" => ggen,
  "toolchain" => Map.take(toolchain, ~w(source elixir erlang mix)),
  "producer" => "docs/sjira/v26.9.21/e2e_project.exs"
}

unless code == 0 and match?(%{"ok" => true}, projection) and File.regular?(out) do
  File.rm_rf!(tmp)

  verdict.(
    Map.merge(identity, %{
      "ok" => false,
      "stage" => "produce",
      "exit" => code,
      "producer_verdict" => projection,
      "tail" => String.slice(output, -2000, 2000)
    }),
    1
  )
end

fresh = File.read!(out)
File.rm_rf!(tmp)

summary =
  Map.merge(identity, %{
    "fixture" => Path.relative_to(fixture, root),
    "digest_form" => projection["digest_form"],
    "work_order_digest" => projection["work_order_digest"],
    "definition_digest" => projection["definition_digest"],
    "sha256" => :crypto.hash(:sha256, fresh) |> Base.encode16(case: :lower)
  })

cond do
  check? and File.read(fixture) == {:ok, fresh} ->
    verdict.(Map.merge(summary, %{"ok" => true, "mode" => "check", "matches" => true}), 0)

  check? ->
    verdict.(Map.merge(summary, %{"ok" => false, "mode" => "check", "matches" => false}), 1)

  true ->
    File.mkdir_p!(Path.dirname(fixture))
    File.write!(fixture, fresh)
    verdict.(Map.merge(summary, %{"ok" => true, "mode" => "write"}), 0)
end
