# Generates test/fixtures/sa2a_route/sa2a_task.json (the SA2A hop of the G5
# conservation court, Xaas.Sa2a.RouteTest) by running the REAL
# GgenIgniter.SemanticJira.admit_work_order/1 and
# GgenIgniter.SemanticA2A.task_from_work_order/2 over the committed sJira order
# fixture test/fixtures/sa2a_route/work_order.json. No task JSON is hand-typed.
#
# Run from a ggen_igniter checkout that has GgenIgniter.SemanticA2A compiled
# (the Friday integration worktree), e.g.:
#
#   cd ~/ggen_igniter && \
#     mix run -e 'Code.eval_file(Path.expand("~/xaas/scripts/gen_sa2a_route_fixture.exs"))'
#
# MIX_DEPS_PATH / MIX_BUILD_PATH may point outside that checkout so the run
# writes nothing into it. The fixture directory is resolved from this script's
# own location, so the output always lands in the xaas tree that holds the script.
#
# The SA2A task carries the vocabulary-contract tuple as its input data part
# (schema "semantic-jira/route-tuple/v1", A2A camelCase keys). The tuple
# projection below is the one hand-written step: task_from_work_order/2 takes
# the data part as its :package and has no tuple projection of its own
# (HANDWRITTEN.md, UNSUPPORTED(generator-capability)).

dir = Path.expand("../test/fixtures/sa2a_route", Path.dirname(__ENV__.file))
order = dir |> Path.join("work_order.json") |> File.read!() |> Jason.decode!()

{:ok, admitted} = GgenIgniter.SemanticJira.admit_work_order(order)
digest = Map.fetch!(admitted, "work_order_digest")

package = %{
  "schema" => "semantic-jira/route-tuple/v1",
  "workOrderDigest" => digest,
  "tuple" => %{
    "subject" => admitted["subject"],
    "postcondition" => admitted["postcondition"],
    "requiresCapability" => admitted["requires_capability"],
    "evidenceCeiling" => admitted["evidence_ceiling"],
    "authorityCeiling" => admitted["authority_ceiling"],
    "consequenceClass" => admitted["consequence_class"],
    "exclusions" => admitted["exclusions"]
  }
}

{:ok, task} =
  GgenIgniter.SemanticA2A.task_from_work_order(admitted, graph_digest: digest, package: package)

{head, 0} = System.cmd("git", ["rev-parse", "HEAD"])
{porcelain, 0} = System.cmd("git", ["status", "--porcelain", "--untracked-files=no"])

provenance = %{
  "generator" => "scripts/gen_sa2a_route_fixture.exs",
  "producer" => "GgenIgniter.SemanticA2A.task_from_work_order/2",
  "admission" => "GgenIgniter.SemanticJira.admit_work_order/1",
  "input" => "test/fixtures/sa2a_route/work_order.json",
  "work_order_digest" => digest,
  "ggen_igniter_dir" => File.cwd!(),
  "ggen_igniter_head" => String.trim(head),
  "ggen_igniter_tracked_clean" => porcelain == ""
}

task_path = Path.join(dir, "sa2a_task.json")
File.write!(task_path, Jason.encode!(task, pretty: true) <> "\n")

File.write!(
  Path.join(dir, "sa2a_task.provenance.json"),
  Jason.encode!(provenance, pretty: true) <> "\n"
)

IO.puts("WROTE #{task_path} work_order_digest=#{digest} ggen_igniter_head=#{String.trim(head)}")
