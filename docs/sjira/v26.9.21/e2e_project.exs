# SJ-001 graph-side projection: real admission + execution descriptor, run as
# ONE `mix run` OS process from the ggen_igniter checkout (the graph side):
#
#   WO=<work-order.json> OUT=<descriptor.json> \
#   [EXPECTED_DIGEST=sha256:..] [ALIAS=sj001] [VERIFIER_SUITE=sjira-e2e] \
#   [CHECKPOINT_SUFFIX=] mix run <abs-path-to-this-file>
#
# Stages, each fail-closed with a one-line JSON verdict on stdout:
#
#   1. admit     GgenIgniter.SemanticJira.admit_work_order/1 admits the work
#                order (representation admission only; no authority, no
#                frontier selection).
#   2. guard     when EXPECTED_DIGEST is given it must equal the digest a
#                FRESH admission computes now -- the altered-after-admission
#                guard. Mismatch => exit 1, no descriptor is written.
#   3. project   the Xaas execution descriptor (the emitter contract documented
#                on Xaas.Ultracode.SemanticWork) with graph_digest AND
#                admission_digest both := the admitted work_order_digest, so
#                the Run's exact subject is the admitted snapshot and Xaas's
#                admission_digest envelope can refuse any post-admission
#                tamper. The bridge carries the graph-side identity
#                (definition_digest, source_snapshot_digest) verbatim; Xaas
#                stores it and never interprets it. The descriptor ALSO carries
#                the admitted snapshot itself (`admitted_work_order`, exactly
#                what admit_work_order/1 returned) so Xaas can RECOMPUTE the
#                work-order digest from the admitted content instead of
#                trusting any digest string (Xaas.Ultracode.SemanticWork.
#                AdmissionBinding); with the envelope omitted or altered
#                consistently, a tamper is still refused.
#
# Dependencies: this driver has no receipt ledger, so a work order with
# non-empty dependencies is refused (upstream receipt evidence would have to
# be supplied by the canonical producer). Exits 1 on every refusal.

wo_path = System.fetch_env!("WO")
out_path = System.fetch_env!("OUT")
alias_name = System.get_env("ALIAS") || "sj001"
suite = System.get_env("VERIFIER_SUITE") || "sjira-e2e"
suffix = System.get_env("CHECKPOINT_SUFFIX") || ""
expected = System.get_env("EXPECTED_DIGEST")

refuse = fn stage, reason, extra ->
  IO.puts(Jason.encode!(Map.merge(%{"ok" => false, "stage" => stage, "reason" => reason}, extra)))
  System.halt(1)
end

work_order = wo_path |> File.read!() |> Jason.decode!()

case GgenIgniter.SemanticJira.admit_work_order(work_order) do
  {:error, reason} ->
    refuse.("admit", inspect(reason), %{})

  {:ok, admitted} ->
    digest = admitted["work_order_digest"]

    cond do
      expected not in [nil, ""] and expected != digest ->
        refuse.("emission_guard", "admission_digest_changed", %{
          "admitted_now" => digest,
          "expected" => expected
        })

      admitted["dependencies"] != [] ->
        refuse.("dependencies", "upstream_receipt_evidence_not_supplied", %{})

      true ->
        {:ok, definition} = GgenIgniter.SemanticJira.definition_digest(work_order)

        descriptor = %{
          "work_order_iri" => "urn:semantic-jira:work-order:" <> admitted["identity"],
          "checkpoint_iri" =>
            "urn:semantic-jira:checkpoint:" <> admitted["identity"] <> "@" <> digest <> suffix,
          "graph_digest" => digest,
          "admission_digest" => digest,
          "admitted_work_order" => admitted,
          "repository_identity" => admitted["repository"],
          "execution_repo_alias" => alias_name,
          "base_sha" => admitted["base_sha"],
          "goal" => admitted["title"] <> ": " <> admitted["description"],
          "provider" => "zcode",
          "verifier_suite" => suite,
          "execution_policy" => "autonomic_wave_attempt",
          "dependencies" => [],
          "bridge" => %{
            "identity" => admitted["identity"],
            "definition_digest" => definition,
            "source_snapshot_digest" => digest,
            "repository" => admitted["repository"],
            "subject" => admitted["subject"],
            "requires" => %{
              "courts" => admitted["required_courts"],
              "acceptance" => admitted["acceptance"],
              "falsifiers" => admitted["falsifiers"]
            }
          }
        }

        File.write!(out_path, Jason.encode!(descriptor, pretty: true))

        IO.puts(
          Jason.encode!(%{
            "ok" => true,
            "identity" => admitted["identity"],
            "work_order_digest" => digest,
            "definition_digest" => definition,
            "descriptor" => out_path
          })
        )
    end
end
