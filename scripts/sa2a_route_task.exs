# The SA2A hop of a live semantic drive (Xaas.Ultracode.SemanticDrive,
# GC23-4 / PRD PR-008 / ARD section 8): runs the REAL
# GgenIgniter.SemanticJira.admit_work_order/1 and
# GgenIgniter.SemanticA2A.task_from_work_order/2 over one sJira work-order
# row and writes the SA2A task JSON. No task JSON is hand-typed.
#
# Run from a ggen_igniter checkout (the drive does this as an OS process):
#
#   MIX_ENV=test mix run --no-start /abs/path/scripts/sa2a_route_task.exs \
#     <work-order.json> <task-out.json>
#
# The SA2A task carries the vocabulary-contract tuple as its input data part
# (schema "semantic-jira/route-tuple/v1", A2A camelCase keys) -- the same
# projection as scripts/gen_sa2a_route_fixture.exs (the committed G5 route
# fixture), plus `workOrder` and `evidenceHorizon` so the task carries the
# whole ARD section 8 SemanticExecutionRequest (its `workOrderDigest` is the
# request's graph_digest). That projection is the one hand-written step:
# task_from_work_order/2 takes the data part as its :package and has no
# tuple projection of its own (HANDWRITTEN.md, UNSUPPORTED(generator-capability)).
#
# Exit 0 and one JSON line {"ok": true, "work_order_digest": ...} on stdout;
# exit 1 and {"ok": false, "reason": ...} when admission or projection refuses.

[order_path, task_path] =
  case System.argv() do
    [order_path, task_path] ->
      [order_path, task_path]

    other ->
      IO.puts(Jason.encode!(%{"ok" => false, "reason" => "usage", "argv" => other}))
      System.halt(2)
  end

order = order_path |> File.read!() |> Jason.decode!()

refuse = fn reason ->
  IO.puts(Jason.encode!(%{"ok" => false, "reason" => inspect(reason)}))
  System.halt(1)
end

admitted =
  case GgenIgniter.SemanticJira.admit_work_order(order) do
    {:ok, admitted} -> admitted
    {:error, reason} -> refuse.({:admission_refused, reason})
  end

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
    "exclusions" => admitted["exclusions"] || [],
    # the rest of the ARD section 8 SemanticExecutionRequest (the Route
    # contract tuple ignores these; the drive's request digest reads them)
    "workOrder" => admitted["identity"],
    "evidenceHorizon" => admitted["evidence_horizon"]
  }
}

task =
  case GgenIgniter.SemanticA2A.task_from_work_order(admitted,
         graph_digest: digest,
         package: package
       ) do
    {:ok, task} -> task
    {:error, reason} -> refuse.({:sa2a_projection_refused, reason})
  end

File.write!(task_path, Jason.encode!(task, pretty: true) <> "\n")

IO.puts(
  Jason.encode!(%{
    "ok" => true,
    "work_order_digest" => digest,
    "definition_digest" => admitted["definition_digest"],
    "task" => task_path
  })
)
