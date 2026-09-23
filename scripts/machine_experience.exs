# The ggen_igniter side of the MachineExperience ratchet
# (Xaas.Ultracode.MachineExperience.Episode, GC23-9 / PRD PR-014 / ARD
# section 15, lane V23-M). Two subcommands, both the REAL ggen_igniter code:
#
#   mix run --no-start /abs/scripts/machine_experience.exs manufacture <attrs.json> <out.json>
#       GgenIgniter.SemanticJira.machine_experience/1 over the attrs map;
#       writes the manufactured record (standing CANDIDATE, authority NONE,
#       experience_digest) to <out.json>.
#
#   mix run --no-start /abs/scripts/machine_experience.exs digest <record.json>
#       GgenIgniter.SemanticJira.digest/1 over the record (the experience
#       digest machine_experience/1 computes); emits it with the record's
#       recorded "experience_digest" and whether they are equal (exit 0
#       equal, exit 1 not). The GC23-9 court uses it to have ggen_igniter's
#       own function recompute the committed sj:MachineExperience node.
#
#   mix run --no-start /abs/scripts/machine_experience.exs validate <data.ttl> [<shapes.ttl>]
#       GgenIgniter.SemanticJira.Shacl.validate_file/2 of the Turtle file
#       against the pack's shapes (default: the checkout's own
#       priv/ggen/semantic-jira-pack/shapes/work-order.shacl.ttl, which holds
#       the FRI-T1 sj:MachineExperienceShape).
#
# Run from a ggen_igniter checkout. Exit 0 and one JSON line with "ok": true
# on stdout; exit 1 and {"ok": false, ...} when the function refuses or the
# data graph does not conform; exit 2 on a usage error. No JSON is
# hand-typed into the record: every digest is ggen_igniter's own.

emit = fn code, map ->
  IO.puts(Jason.encode!(map))
  System.halt(code)
end

sha256_file = fn path ->
  "sha256:" <> (:crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower))
end

case System.argv() do
  ["manufacture", attrs_path, out_path] ->
    attrs = attrs_path |> File.read!() |> Jason.decode!()

    case GgenIgniter.SemanticJira.machine_experience(attrs) do
      {:ok, experience} ->
        File.write!(out_path, Jason.encode!(experience, pretty: true) <> "\n")

        emit.(0, %{
          "ok" => true,
          "experience_digest" => experience["experience_digest"],
          "experience" => out_path
        })

      {:error, reason} ->
        emit.(1, %{"ok" => false, "reason" => inspect(reason)})
    end

  ["digest", record_path] ->
    record = record_path |> File.read!() |> Jason.decode!()
    computed = GgenIgniter.SemanticJira.digest(record)
    equal = computed == record["experience_digest"]

    emit.(if(equal, do: 0, else: 1), %{
      "ok" => equal,
      "experience_digest" => computed,
      "recorded" => record["experience_digest"],
      "record_sha256" => sha256_file.(record_path)
    })

  ["validate", data_path | rest] ->
    shapes =
      case rest do
        [shapes] -> shapes
        [] -> GgenIgniter.SemanticJira.Shacl.pack_shapes_path()
      end

    report = GgenIgniter.SemanticJira.Shacl.validate_file(data_path, shapes)

    emit.(if(report.conforms, do: 0, else: 1), %{
      "ok" => report.conforms,
      "conforms" => report.conforms,
      "shapes_checked" => report.shapes_checked,
      "focus_node_count" => report.focus_node_count,
      "violations" => Enum.map(report.violations, &inspect/1),
      "shapes" => Path.expand(shapes),
      "shapes_sha256" => sha256_file.(shapes),
      "data_sha256" => sha256_file.(data_path)
    })

  other ->
    emit.(2, %{"ok" => false, "reason" => "usage", "argv" => other})
end
