defmodule Xaas.PackTest do
  @moduledoc """
  Chicago qualification of `Xaas.Pack` (Pack -> ggen -> XaaS -> BRCE -> Receipt):
  the committed pack bytes under the committed out-of-band pin, the real
  ggen_igniter query engine over the real TTL, the real
  `SemanticDrive.anchor_from/2` / `MachineExperience` / `SubstitutionCourt`
  judges, and the real `Xaas.Actuation.run/4` Reactor kernel on the sandboxed
  Postgres data layer. Mutations are made to real copies of the pack on disk.

  Every refusal test that asserts "no DO" counts real ActuationIntent /
  ActuationReceipt rows AND runs a positive control in the same test.
  The direct-Ash bypass of `:actuate_status` is qualified by
  `test/xaas/actuation_test.exs` and is deliberately not repeated here.
  """

  use ExUnit.Case, async: true

  alias Xaas.Marketplace.{ApprovalProviderStatusChange, Provider}
  alias Xaas.Marketplace.Changes.ApplyProviderStatusChange
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}
  alias Xaas.Pack
  alias Xaas.Tunnel.Receipt
  alias Xaas.Ultracode.SemanticDrive

  @moduletag :tmp_dir

  # The committed pin literal (config/config.exs :capability_pack_pins). Kept
  # here too so a silent re-pin of the config is a failing test, not a pass.
  @committed_pin "sha256:ca8f9cd09fb2529a0be5b210b6a8874d9198b7184ea8d9d5997f38565dcc4946"

  @source Path.expand("../../../priv/packs/xaas_capability_pack", __DIR__)
  @profile "profiles/provider_status.ttl"
  @graph_digest "sha256:" <> String.duplicate("ab", 32)
  # A fixed subject for pure admit/3 tests (the court only casts it to the
  # resource's primary key type; no row is read).
  @subject_uuid "00000000-0000-4000-8000-000000000001"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    {:ok, pack} = Pack.load("provider_status")
    %{pack: pack}
  end

  # sJira WorkOrder row, snake_case per Xaas.Sa2a.Route @snake_keys.
  defp row(overrides \\ %{}) do
    Map.merge(
      %{
        "identity" => "PACK-1",
        "subject" => "seanchatmangpt/xaas@pack/provider-status#PACK-1",
        "postcondition" => "the provider's lifecycle status is the requested one, receipted",
        "requires_capability" => "xaas:provider-actuate-status",
        "evidence_ceiling" => "EXECUTED_VERIFIED",
        "evidence_horizon" => "the sealed ActuationReceipt of this DO",
        "authority_ceiling" => "DO",
        "consequence_class" => "actuation",
        "exclusions" => [
          "no model output is authority",
          "no direct Ash call bypassing Xaas.Actuation.run/4"
        ],
        "path_scope" => [subject(@subject_uuid)]
      },
      overrides
    )
  end

  defp subject(id), do: "resource:Xaas.Marketplace.Provider/#{id}"

  defp provider!(name \\ "Pack Provider"),
    do: Xaas.Generator.create_provider!(%{name: name, org_id: "org-pack"})

  # The real maker-checker path: file a request, approve it with a distinct
  # checker. The approval's own change runs the DO through Xaas.Actuation.run/4.
  defp request!(provider, status \\ :active) do
    ApprovalProviderStatusChange
    |> Ash.Changeset.for_create(:create, %{
      org_id: provider.org_id,
      provider_id: provider.id,
      requested_by: "maker",
      requested_status: status
    })
    |> Ash.create!(authorize?: false)
  end

  defp approve!(approval, checker \\ "checker") do
    approval
    |> Ash.Changeset.for_update(:approve, %{approved_by: checker})
    |> Ash.update!(authorize?: false)
  end

  defp approved!(provider), do: provider |> request!() |> approve!()

  defp authority(approval),
    do: %{"kind" => "maker_checker_approval", "approval_id" => approval.id}

  defp counts,
    do:
      {Ash.count!(ActuationIntent, authorize?: false),
       Ash.count!(ActuationReceipt, authorize?: false)}

  defp status(provider),
    do: Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status)

  defp copy!(tmp_dir) do
    dir = Path.join(tmp_dir, "pack")
    File.mkdir_p!(tmp_dir)
    File.cp_r!(@source, dir)
    dir
  end

  defp mutate!(dir, rel, fun) do
    path = Path.join(dir, rel)
    before = File.read!(path)
    after_ = fun.(before)
    assert after_ != before, "mutation of #{rel} was vacuous"
    File.write!(path, after_)
    dir
  end

  defp replace!(dir, rel, from, to), do: mutate!(dir, rel, &String.replace(&1, from, to))
  defp append!(dir, rel, text), do: mutate!(dir, rel, &(&1 <> text))

  defp for_subject(provider), do: row(%{"path_scope" => [subject(provider.id)]})

  defp actuate(pack, row, caller, opts \\ []) do
    {graph_digest, opts} = Keyword.pop(opts, :graph_digest, @graph_digest)

    Pack.actuate(
      pack,
      row,
      graph_digest,
      caller,
      Keyword.put_new(opts, :input, %{status: :active})
    )
  end

  describe "load/2 (Pack -> pin)" do
    test "the committed pack admits against the committed pin literal", %{pack: pack} do
      assert Application.fetch_env!(:xaas, :capability_pack_pins)["provider_status"].digest ==
               @committed_pin

      assert pack.pinned?
      assert pack.digest == @committed_pin
      assert pack.pack_id == "xaas_capability_pack"
      assert pack.confers == "NONE"
      assert pack.authority_ceiling == [:observe, :select]

      assert Map.new(pack.declarations, fn {c, d} -> {c, d["standing"]} end) == %{
               "xaas:provider-actuate-status" => "ADMITTED",
               "xaas:ledger-transfer" => "REFUSED",
               "xaas:provider-destroy" => "UNSUPPORTED"
             }

      admitted = pack.declarations["xaas:provider-actuate-status"]
      assert admitted["resource"] == Provider
      assert admitted["action"] == :actuate_status
    end

    test "TTL drift under the committed pin is refused; an unmutated copy is the control",
         %{tmp_dir: tmp_dir} do
      control = copy!(Path.join(tmp_dir, "control"))

      assert {:ok, %Pack{digest: @committed_pin}} =
               Pack.load("provider_status", pack_dir: control)

      drifted =
        tmp_dir
        |> copy!()
        |> replace!(@profile, ~s("sensitive_resource"), ~s("reconsidered"))

      assert {:refused, {:pack_digest_mismatch, @committed_pin, observed}} =
               Pack.load("provider_status", pack_dir: drifted)

      assert observed =~ ~r/\Asha256:[0-9a-f]{64}\z/
      refute observed == @committed_pin
    end

    test "a gate query is part of the pinned content", %{tmp_dir: tmp_dir} do
      drifted = tmp_dir |> copy!() |> append!("gates/020_pack.rq", "# drift\n")

      assert {:refused, {:pack_digest_mismatch, @committed_pin, _observed}} =
               Pack.load("provider_status", pack_dir: drifted)
    end

    test "an unpinned name is refused" do
      assert Pack.load("no_such_pack") == {:refused, {:pack_unpinned, "no_such_pack"}}
    end

    test "an unpinned read is judged but never admitted" do
      assert {:ok, %Pack{pinned?: false} = unpinned} = Pack.read(@source, @profile)
      assert Pack.admit(unpinned, row(), @graph_digest) == {:refused, :pack_not_pinned}
    end
  end

  describe "canonical form and alignment" do
    test "a blank node is a non-canonical value", %{tmp_dir: tmp_dir} do
      dir =
        tmp_dir
        |> copy!()
        |> append!(@profile, ~s(\nps:provider-destroy xcp:tool [ xcp:tool "x" ] .\n))

      assert {:refused, {:pack_unloadable, {:non_canonical_value, "_:" <> _}}} =
               Pack.read(dir, @profile)
    end

    test "only skos:closeMatch is admitted as alignment", %{pack: pack, tmp_dir: tmp_dir} do
      assert Enum.all?(
               pack.alignments,
               &(&1["predicate"] == "http://www.w3.org/2004/02/skos/core#closeMatch")
             )

      assert %{"object" => "https://ggen.io/ontology/xaas-ultracode#EngineeringEpoch"} =
               Enum.find(pack.alignments, &String.ends_with?(&1["subject"], "#DeliveryFacet"))

      dir =
        tmp_dir
        |> copy!()
        |> append!(
          "ontology.ttl",
          "\nxcp:CapabilityDeclaration owl:equivalentClass prov:Plan .\n"
        )

      assert Pack.read(dir, @profile) ==
               {:refused,
                {:pack_unloadable,
                 {:non_close_match_alignment, "http://www.w3.org/2002/07/owl#equivalentClass",
                  "http://www.w3.org/ns/prov#Plan"}}}
    end

    test "a pack cannot confer authority or carry DO in its passport ceiling", %{tmp_dir: tmp_dir} do
      confers =
        tmp_dir
        |> Path.join("a")
        |> copy!()
        |> replace!("ontology.ttl", ~s(xcp:confers "NONE"), ~s(xcp:confers "DO"))

      assert Pack.read(confers, @profile) ==
               {:refused, {:pack_unloadable, {:pack_confers_authority, "DO"}}}

      laundering =
        tmp_dir
        |> Path.join("b")
        |> copy!()
        |> replace!("ontology.ttl", ~s("observe" , "select"), ~s("observe" , "do"))

      assert Pack.read(laundering, @profile) ==
               {:refused, {:pack_unloadable, :do_authority_laundering}}

      invalid =
        tmp_dir
        |> Path.join("c")
        |> copy!()
        |> replace!("ontology.ttl", ~s("observe" , "select"), ~s("observe" , "admin"))

      assert Pack.read(invalid, @profile) ==
               {:refused, {:pack_unloadable, :authority_ceiling_invalid}}
    end

    test "a facet outside the ROADMAP planes is refused", %{tmp_dir: tmp_dir} do
      dir =
        tmp_dir
        |> copy!()
        |> replace!(
          "ontology.ttl",
          ~s(rdfs:label "receipt" ; xcp:roadmapPlane 8),
          ~s(rdfs:label "receipt" ; xcp:roadmapPlane 10)
        )

      assert Pack.read(dir, @profile) ==
               {:refused, {:pack_unloadable, {:facet_outside_roadmap_planes, "ReceiptFacet", 10}}}
    end
  end

  describe "declarations: resource/action rules apply to ADMITTED only" do
    test "ADMITTED needs resource/action; REFUSED/UNSUPPORTED need refusalReason only",
         %{tmp_dir: tmp_dir} do
      no_action =
        tmp_dir
        |> Path.join("a")
        |> copy!()
        |> replace!(@profile, ~s(  xcp:action "actuate_status" ;\n), "")

      assert Pack.read(no_action, @profile) ==
               {:refused,
                {:pack_unloadable,
                 {:declaration_incomplete, "xaas:provider-actuate-status", "action"}}}

      no_reason =
        tmp_dir
        |> Path.join("b")
        |> copy!()
        |> replace!(
          @profile,
          ~s(xcp:facet xcp:AuthorityFacet ;\n  xcp:refusalReason "sensitive_resource" .),
          ~s(xcp:facet xcp:AuthorityFacet .)
        )

      assert Pack.read(no_reason, @profile) ==
               {:refused,
                {:pack_unloadable,
                 {:declaration_incomplete, "xaas:ledger-transfer", "refusalReason"}}}

      # a REFUSED entry's resource is never resolved (control: it loads)
      unresolved =
        tmp_dir
        |> Path.join("c")
        |> copy!()
        |> replace!(
          @profile,
          ~s(xcp:facet xcp:AuthorityFacet ;),
          ~s(xcp:facet xcp:AuthorityFacet ;\n  xu:resourceModule "Xaas.No.Such.Resource" ;)
        )

      assert {:ok, %Pack{} = pack} = Pack.read(unresolved, @profile)
      assert pack.declarations["xaas:ledger-transfer"]["refusal_reason"] == "sensitive_resource"
    end

    test "an ADMITTED binding must resolve to a real Ash resource action fenced by ReactorContext",
         %{tmp_dir: tmp_dir} do
      binding = ~s(xu:resourceModule "Xaas.Marketplace.Provider")

      for {sub, from, to, expected} <- [
            {"a", binding, ~s(xu:resourceModule "Xaas.No.Such.Resource"),
             {:unknown_resource, "Xaas.No.Such.Resource"}},
            {"b", binding, ~s(xu:resourceModule "Enum"), {:unknown_resource, "Enum"}},
            {"c", ~s(xcp:action "actuate_status"), ~s(xcp:action "no_such_action_zq"),
             {:unknown_action, "Xaas.Marketplace.Provider", "no_such_action_zq"}},
            {"d", ~s(xcp:action "actuate_status"), ~s(xcp:action "update"),
             {:action_not_fenced, "Xaas.Marketplace.Provider", "update"}}
          ] do
        dir = tmp_dir |> Path.join(sub) |> copy!() |> replace!(@profile, from, to)
        assert Pack.read(dir, @profile) == {:refused, {:pack_unloadable, expected}}
      end
    end
  end

  describe "admit/3 (XaaS court)" do
    test "SemanticDrive.anchor_from/2 refusals pass through unchanged", %{pack: pack} do
      bad = Map.delete(row(), "postcondition")
      assert {:refused, %{} = typed} = SemanticDrive.anchor_from(bad, @graph_digest)
      assert Pack.admit(pack, bad, @graph_digest) == {:refused, typed}
    end

    test "the work bound is the WorkOrder's; graph_digest is excluded from work identity",
         %{pack: pack} do
      assert {:ok, admission} = Pack.admit(pack, row(), @graph_digest)
      assert admission["authority_bound"] == "DO"
      assert admission["pack_confers"] == "NONE"
      assert admission["resource"] == Provider and admission["action"] == :actuate_status
      assert admission["work_identity_digest"] =~ ~r/\Asha256:[0-9a-f]{64}\z/

      other = "sha256:" <> String.duplicate("cd", 32)
      assert {:ok, again} = Pack.admit(pack, row(), other)
      assert again["work_identity_digest"] == admission["work_identity_digest"]
      refute again["anchor"]["request_digest"] == admission["anchor"]["request_digest"]
    end

    test "declared standings and the WorkOrder ceiling decide; the pack confers none", %{
      pack: pack
    } do
      assert {:ok, _} = Pack.admit(pack, row(), @graph_digest)

      assert Pack.admit(
               pack,
               row(%{"requires_capability" => "xaas:ledger-transfer"}),
               @graph_digest
             ) ==
               {:refused, {:capability_refused, "xaas:ledger-transfer", "sensitive_resource"}}

      assert Pack.admit(
               pack,
               row(%{"requires_capability" => "xaas:provider-destroy"}),
               @graph_digest
             ) ==
               {:unsupported,
                {:capability_unsupported, "xaas:provider-destroy", "no_reactor_fenced_action"}}

      assert Pack.admit(pack, row(%{"requires_capability" => "xaas:nope"}), @graph_digest) ==
               {:refused, {:capability_not_declared, "xaas:nope"}}

      assert Pack.admit(pack, row(%{"authority_ceiling" => "CONSTRUCT"}), @graph_digest) ==
               {:refused, {:authority_ceiling_insufficient, "CONSTRUCT"}}
    end

    test "class, scope and required exclusions must fit the declaration", %{pack: pack} do
      for overrides <- [
            %{"consequence_class" => "manufacture"},
            %{"path_scope" => ["resource:Xaas.Ledger.Transfer"]},
            %{"path_scope" => []},
            %{"exclusions" => ["no model output is authority"]}
          ] do
        assert {:refused, {:consequence_out_of_bounds, bounds}} =
                 Pack.admit(pack, row(overrides), @graph_digest)

        assert bounds["authority_ceiling"] == "DO"
      end
    end
  end

  describe "actuate/5 (BRCE -> Receipt)" do
    @kind "maker_checker_approval"

    test "authority falsifiers write nothing; a verified approval is the control", %{pack: pack} do
      provider = provider!()
      pending = request!(provider)
      wo = for_subject(provider)
      before = counts()

      assert actuate(pack, wo, %{"pack_binding" => %{}}) == {:refused, :authority_missing}
      assert actuate(pack, wo, %{}) == {:refused, :authority_missing}
      assert actuate(pack, wo, nil) == {:refused, :authority_missing}

      assert actuate(
               pack,
               wo,
               Map.put(authority(pending), "pack_binding", %{"pack" => pack.digest})
             ) == {:refused, :pack_binding_is_not_authority}

      assert actuate(pack, wo, %{pack_binding: %{}, kind: @kind}) ==
               {:refused, :pack_binding_is_not_authority}

      assert actuate(pack, wo, %{"kind" => "pack"}) ==
               {:refused, {:authority_kind_not_admitted, "pack"}}

      assert actuate(pack, wo, %{"source" => "no kind"}) ==
               {:refused, {:authority_kind_not_admitted, nil}}

      # a borrowed lease kind: Lease.actuate/2 is its only producer
      assert actuate(pack, wo, %{"kind" => "ultracode_lease_actuation", "provider" => "zcode"}) ==
               {:refused, {:authority_kind_not_admitted, "ultracode_lease_actuation"}}

      # a bare maker-checker label is not an approval
      assert actuate(pack, wo, %{"kind" => @kind}) ==
               {:refused, {:authority_evidence_unverified, @kind, :approval_id_missing}}

      assert actuate(pack, wo, %{"kind" => @kind, "approver" => "pack-test", "ticket" => "PACK-1"}) ==
               {:refused, {:authority_evidence_unverified, @kind, :approval_id_missing}}

      assert actuate(pack, wo, authority(%{id: Ecto.UUID.generate()})) ==
               {:refused, {:authority_evidence_unverified, @kind, :approval_not_found}}

      assert actuate(pack, wo, authority(pending)) ==
               {:refused, {:authority_evidence_unverified, @kind, :approval_not_approved}}

      assert counts() == before
      assert status(provider) == :pending

      # control: the checker approves (the approval's own DO); the pack joins it
      {intents, receipts} = before
      approved = approve!(pending)
      assert counts() == {intents + 1, receipts + 1}
      assert status(provider) == :active

      assert {:ok, receipt} = actuate(pack, wo, authority(approved))
      assert receipt["standing"] == "ALIVE"
      assert receipt["replay"]["replayed"] == true
      assert counts() == {intents + 1, receipts + 1}

      # every claimed field must equal the record
      assert actuate(pack, wo, Map.put(authority(approved), "approved_by", "mallory")) ==
               {:refused,
                {:authority_evidence_unverified, @kind, {:claim_mismatch, "approved_by"}}}

      assert actuate(pack, wo, Map.put(authority(approved), "ticket", "PACK-1")) ==
               {:refused, {:authority_evidence_unverified, @kind, {:claim_mismatch, "ticket"}}}

      assert counts() == {intents + 1, receipts + 1}
    end

    test "a forged or edited pack struct is re-derived from the pin and refused; the pinned pack is the control",
         %{pack: pack} do
      provider = provider!("Unforged")
      approval = approved!(provider)
      wo = for_subject(provider)
      before = counts()
      zeros = "sha256:" <> String.duplicate("0", 64)
      decl = pack.declarations["xaas:provider-actuate-status"]
      rebound = Map.put(pack.declarations, decl["capability"], %{decl | "action" => :update})

      forged = [
        %{pack | digest: zeros},
        %{pack | digest: zeros, declarations: rebound},
        %{pack | declarations: rebound},
        %Pack{name: "provider_status", pinned?: true, digest: zeros, declarations: rebound},
        %Pack{
          name: "provider_status",
          pinned?: true,
          pack_dir: pack.pack_dir,
          digest: pack.digest,
          declarations: rebound
        }
      ]

      for struct <- forged do
        assert Pack.admit(struct, wo, @graph_digest) ==
                 {:refused, {:pack_struct_mismatch, "provider_status"}}

        assert actuate(struct, wo, authority(approval), input: %{name: "PWNED"}) ==
                 {:refused, {:pack_struct_mismatch, "provider_status"}}
      end

      {:ok, unpinned} = Pack.read(@source, @profile)
      assert actuate(unpinned, wo, authority(approval)) == {:refused, :pack_not_pinned}

      assert actuate(%{unpinned | pinned?: true}, wo, authority(approval)) ==
               {:refused, :pack_not_pinned}

      assert {:refused, {:authority_ceiling_insufficient, "CONSTRUCT"}} =
               actuate(
                 pack,
                 Map.put(wo, "authority_ceiling", "CONSTRUCT"),
                 authority(approval)
               )

      assert {:refused, {:capability_refused, _, _}} =
               actuate(
                 pack,
                 Map.put(wo, "requires_capability", "xaas:ledger-transfer"),
                 authority(approval)
               )

      assert {:refused, :input_not_a_map} =
               actuate(pack, wo, authority(approval), input: [:status])

      assert counts() == before

      assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:name) ==
               "Unforged"

      assert {:ok, %{"standing" => "ALIVE"}} = actuate(pack, wo, authority(approval))
    end

    test "the subject is the WorkOrder's: another row is refused; two subjects are two keys and two DOs",
         %{pack: pack} do
      initial = counts()
      a = provider!("A")
      b = provider!("B")
      approval_a = approved!(a)
      before = counts()

      assert actuate(pack, for_subject(a), authority(approval_a), subject_id: b.id) ==
               {:refused, {:subject_not_in_work_order, b.id}}

      assert actuate(pack, for_subject(b), authority(approval_a)) ==
               {:refused, {:authority_evidence_unverified, @kind, :subject_mismatch}}

      assert actuate(
               pack,
               row(%{"path_scope" => ["resource:Xaas.Marketplace.Provider"]}),
               authority(approval_a)
             ) == {:refused, :work_order_subject_missing}

      assert actuate(
               pack,
               row(%{"path_scope" => [subject(a.id), subject(b.id)]}),
               authority(approval_a)
             ) ==
               {:refused,
                {:work_order_subject_ambiguous, Enum.sort([subject(a.id), subject(b.id)])}}

      assert actuate(pack, row(%{"path_scope" => [subject("not-a-key")]}), authority(approval_a)) ==
               {:refused, {:work_order_subject_invalid, subject("not-a-key")}}

      assert counts() == before
      assert status(b) == :pending

      approval_b = approved!(b)
      assert {:ok, ra} = actuate(pack, for_subject(a), authority(approval_a), subject_id: a.id)
      assert {:ok, rb} = actuate(pack, for_subject(b), authority(approval_b))

      refute ra["replay"]["idempotency_key"] == rb["replay"]["idempotency_key"]
      refute ra["identity"]["work_identity_digest"] == rb["identity"]["work_identity_digest"]

      refute ra["consequence"]["actuation_intent_id"] ==
               rb["consequence"]["actuation_intent_id"]

      assert {ra["identity"]["subject_id"], rb["identity"]["subject_id"]} == {a.id, b.id}
      assert ra["replay"]["replayed"] and rb["replay"]["replayed"]

      {intents, receipts} = initial
      assert counts() == {intents + 2, receipts + 2}
      assert {status(a), status(b)} == {:active, :active}
    end

    test "the receipt names the recorded authority, the WorkOrder subject and the pack evidence",
         %{pack: pack} do
      provider = provider!()
      approval = approved!(provider)
      assert {:ok, receipt} = actuate(pack, for_subject(provider), authority(approval))

      assert Pack.verify_receipt(receipt) == :ok
      assert receipt["schema"] == "xaas.capability-pack-receipt/1"

      assert receipt["replay"]["idempotency_key"] ==
               "approval-provider-status-change:#{approval.id}"

      assert receipt["consequence"]["actuation_status"] == "succeeded"
      assert receipt["consequence"]["resource"] == "Xaas.Marketplace.Provider"
      assert receipt["identity"]["subject_id"] == provider.id
      assert receipt["identity"]["subject"] == subject(provider.id)
      assert receipt["authority"]["kind"] == @kind
      assert receipt["authority"]["pack_confers"] == "NONE"
      assert receipt["evidence"]["pack_digest"] == @committed_pin
      assert receipt["evidence"]["graph_digest_standing"] == "CALLER_ASSERTED"

      intent =
        Ash.get!(ActuationIntent, receipt["consequence"]["actuation_intent_id"],
          authorize?: false
        )

      recorded = Receipt.json_safe(intent.authority)
      assert recorded == Receipt.json_safe(ApplyProviderStatusChange.authority(approval))
      assert recorded["approved_by"] == "checker"
      assert receipt["authority"]["authority_digest"] == "sha256:" <> Receipt.digest(recorded)
      refute Map.has_key?(recorded, "pack_binding")
      assert intent.idempotency_key == receipt["replay"]["idempotency_key"]

      tampered =
        put_in(receipt, ["evidence", "graph_digest"], "sha256:" <> String.duplicate("00", 32))

      assert Pack.verify_receipt(tampered) == {:refused, :replay_digest_mismatch}

      assert Pack.verify_receipt(Map.delete(receipt, "receipt_sha256")) ==
               {:refused, :replay_digest_mismatch}
    end

    test "replay: one approval is one consequence; an authority the DO did not run under is refused",
         %{pack: pack} do
      provider = provider!()
      approval = approved!(provider)
      wo = for_subject(provider)
      assert {:ok, first} = actuate(pack, wo, authority(approval))
      before = counts()

      # graph_digest is caller-asserted and not in the key: still the same consequence
      assert {:ok, again} =
               actuate(pack, wo, authority(approval),
                 graph_digest: "sha256:" <> String.duplicate("cd", 32)
               )

      assert again["replay"]["replayed"] == true
      assert again["replay"]["idempotency_key"] == first["replay"]["idempotency_key"]

      assert again["consequence"]["actuation_receipt_id"] ==
               first["consequence"]["actuation_receipt_id"]

      # an input the approval does not name is not a separate DO; it is refused
      for input <- [%{status: :suspended}, %{status: :active, name: "x"}, %{}] do
        assert actuate(pack, wo, authority(approval), input: input) ==
                 {:refused, {:authority_evidence_unverified, @kind, :input_mismatch}}
      end

      # re-approval by another checker replays the kernel DO (no new
      # consequence) but the record now names an authority the DO did not run
      # under: the pack refuses rather than receipt it
      reapproved = approve!(approval, "checker-2")
      assert counts() == before
      assert actuate(pack, wo, authority(reapproved)) == {:refused, :replay_authority_mismatch}
      assert counts() == before

      intent =
        Ash.get!(ActuationIntent, first["consequence"]["actuation_intent_id"], authorize?: false)

      assert Receipt.json_safe(intent.authority)["approved_by"] == "checker"
      assert first["authority"] == again["authority"]
    end
  end
end
