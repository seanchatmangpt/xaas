defmodule Xaas.Ultracode.SbbRealizationTest do
  @moduledoc """
  Chicago-style court for RFC v26.9.26 qualified SBB runtime realization.
  Real structs, real digests, real SubstitutionCourt; state-based assertions
  only. Includes adversarial falsifiers (wrong digest, stale subject,
  unauthorized DO, out-of-contract behavior, duplicate delivery, reordering,
  replay tamper) and a deterministic throughput regression bound.
  """
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.SbbRealization, as: S
  alias Xaas.Ultracode.SbbRealization.{Abb, Admitted, ArchitectureContract, Ledger, Manifest}
  alias Xaas.Ultracode.SubstitutionCourt.{PartPassport, QualificationReceipt, WorkIdentity}

  @d1 "sha256:" <> String.duplicate("1", 64)
  @d2 "sha256:" <> String.duplicate("2", 64)
  @d3 "sha256:" <> String.duplicate("3", 64)
  @d4 "sha256:" <> String.duplicate("4", 64)
  @d5 "sha256:" <> String.duplicate("5", 64)
  @d6 "sha256:" <> String.duplicate("6", 64)
  @d9 "sha256:" <> String.duplicate("9", 64)
  @sha_a String.duplicate("a", 40)
  @sha_b String.duplicate("b", 40)
  @sha_c String.duplicate("c", 40)
  @sha_e String.duplicate("e", 40)

  defp abb(o \\ %{}) do
    struct!(
      Abb,
      Map.merge(
        %{
          abb_id: "abb:runtime.queue",
          exact_subject: "seanchatmangpt/xaas@#{@sha_a}",
          layer: :runtime,
          capability: "durable work queue"
        },
        o
      )
    )
  end

  defp contract(o \\ %{}) do
    struct!(
      ArchitectureContract,
      Map.merge(
        %{
          contract_id: "contract:runtime.queue/1",
          abb_id: "abb:runtime.queue",
          exact_subject: "seanchatmangpt/xaas@#{@sha_a}",
          allowed_behaviors: [:enqueue, :dequeue, :ack],
          authority_ceiling: [:observe, :select, :construct],
          consequence_schema_digest: @d1,
          receipt_schema_digest: @d2
        },
        o
      )
    )
  end

  defp qual(o \\ %{}),
    do:
      struct!(
        QualificationReceipt,
        Map.merge(
          %{receipt_digest: @d3, verifier_evidence_digest: @d4, replay_digest: @d5, passed: true},
          o
        )
      )

  defp passport(id, sha, q, o \\ %{}) do
    struct!(
      PartPassport,
      Map.merge(
        %{
          part_id: id,
          kind: :provider,
          exact_subject: "seanchatmangpt/#{id}@#{sha}",
          part_digest: @d6,
          producer_digest: @d4,
          consequence_schema_digest: @d1,
          receipt_schema_digest: @d2,
          authority_ceiling: [:observe, :select, :construct],
          qualification_receipt: q
        },
        o
      )
    )
  end

  defp manifest(o \\ %{}) do
    q = Map.get(o, :qualification_receipt, qual())
    impl = Map.get(o, :implementation, passport("provider-a", @sha_b, q))

    struct!(
      Manifest,
      Map.merge(
        %{
          sbb_id: "sbb:queue/provider-a",
          abb_id: "abb:runtime.queue",
          abb_digest: S.abb_digest(abb()),
          contract_subject: "seanchatmangpt/xaas@#{@sha_a}",
          contract_digest: S.contract_digest(contract()),
          qualification_digest: S.qualification_digest(q),
          qualification_receipt: q,
          implementation: impl,
          requested_behaviors: [:enqueue, :ack],
          requested_authority: [:select, :construct]
        },
        o
      )
    )
  end

  defp work(o \\ %{}) do
    struct!(
      WorkIdentity,
      Map.merge(
        %{
          work_order_id: "urn:work:sbb-1",
          exact_subject: "seanchatmangpt/xaas@#{@sha_a}",
          origin_authority: "sj:objective-code-work-authority",
          consequence_schema_digest: @d1,
          receipt_schema_digest: @d2,
          execution_manifest_digest: @d3
        },
        o
      )
    )
  end

  defp admitted!(m \\ manifest()) do
    {:ok, a} = S.admit(m, abb(), contract())
    a
  end

  describe "admission (DoD 1, 4, 10)" do
    test "qualified manifest with exact digests is admitted without authority" do
      assert {:ok, %Admitted{admission_digest: ad}} = S.admit(manifest(), abb(), contract())
      assert ad =~ ~r/^sha256:[0-9a-f]{64}$/
    end

    test "wrong ABB digest is refused" do
      assert {:error, :abb_digest_mismatch} =
               S.admit(manifest(%{abb_digest: @d9}), abb(), contract())
    end

    test "ABB mutated after the manifest was qualified is refused" do
      assert {:error, :abb_digest_mismatch} =
               S.admit(manifest(), abb(%{capability: "drifted"}), contract())
    end

    test "wrong contract digest is refused" do
      assert {:error, :contract_digest_mismatch} =
               S.admit(manifest(%{contract_digest: @d9}), abb(), contract())
    end

    test "contract widened after qualification is refused (digest re-computed)" do
      widened = contract(%{allowed_behaviors: [:enqueue, :dequeue, :ack, :purge]})
      assert {:error, :contract_digest_mismatch} = S.admit(manifest(), abb(), widened)
    end

    test "stale contract subject is refused before digest comparison" do
      fresh = contract(%{exact_subject: "seanchatmangpt/xaas@#{@sha_e}"})
      assert {:error, :stale_contract_subject} = S.admit(manifest(), abb(), fresh)
    end

    test "non-exact subject (branch name) is refused" do
      assert {:error, :contract_subject_not_exact} =
               S.admit(
                 manifest(%{contract_subject: "seanchatmangpt/xaas@main"}),
                 abb(),
                 contract()
               )
    end

    test "qualification digest that does not recompute is refused" do
      assert {:error, :qualification_digest_mismatch} =
               S.admit(manifest(%{qualification_digest: @d9}), abb(), contract())
    end

    test "failed qualification is refused" do
      q = qual(%{passed: false})

      assert {:error, :qualification_not_pass} =
               S.admit(manifest(%{qualification_receipt: q}), abb(), contract())
    end

    test "implementation passport bound to a different qualification is refused" do
      other = passport("provider-a", @sha_b, qual(%{replay_digest: @d9}))

      assert {:error, :qualification_not_bound_to_implementation} =
               S.admit(manifest(%{implementation: other}), abb(), contract())
    end

    test "behavior outside the ArchitectureContract is refused" do
      assert {:error, :behavior_outside_contract} =
               S.admit(manifest(%{requested_behaviors: [:enqueue, :purge]}), abb(), contract())
    end

    test "empty, duplicated or non-atom behavior lists are refused" do
      assert {:error, :behaviors_empty} =
               S.admit(manifest(%{requested_behaviors: []}), abb(), contract())

      assert {:error, :behaviors_invalid} =
               S.admit(manifest(%{requested_behaviors: [:ack, :ack]}), abb(), contract())

      assert {:error, :behaviors_invalid} =
               S.admit(manifest(%{requested_behaviors: ["ack"]}), abb(), contract())
    end

    test "requesting DO is refused: qualification is not execution authority" do
      assert {:error, :do_requires_brce} =
               S.admit(manifest(%{requested_authority: [:select, :do]}), abb(), contract())
    end

    test "a contract whose ceiling includes DO is itself refused" do
      c = contract(%{authority_ceiling: [:select, :do]})
      m = manifest(%{contract_digest: S.contract_digest(c)})
      assert {:error, :do_requires_brce} = S.admit(m, abb(), c)
    end

    test "authority above the contract ceiling is refused" do
      c = contract(%{authority_ceiling: [:observe]})
      m = manifest(%{contract_digest: S.contract_digest(c)})
      assert {:error, :authority_ceiling_increase} = S.admit(m, abb(), c)
    end

    test "unknown layer and malformed input are refused" do
      bad = abb(%{layer: :quantum})

      assert {:error, :layer_invalid} =
               S.admit(manifest(%{abb_digest: S.abb_digest(bad)}), bad, contract())

      assert {:error, :malformed_input} = S.admit(%{}, abb(), contract())

      assert {:error, :abb_mismatch} =
               S.admit(manifest(%{abb_id: "abb:other"}), abb(), contract())
    end

    test "all seven RFC layers are admissible" do
      assert S.layers() == [
               :capability,
               :resource,
               :runtime,
               :delivery,
               :product,
               :governance,
               :intelligence
             ]

      for layer <- S.layers() do
        a = abb(%{layer: layer})
        assert {:ok, _} = S.admit(manifest(%{abb_digest: S.abb_digest(a)}), a, contract())
      end
    end
  end

  describe "realization (DoD 2, 3, 8, 10)" do
    test "materializes one bounded realization carrying no DO authority" do
      assert {:ok, r} = S.realize(admitted!(), work(), 1)
      assert r.authority == "NONE"
      assert r.grants_do_authority == false
      assert r.do_route == "BRCE"
      assert r.authority_ceiling == ["construct", "select"]
      assert r.behaviors == ["ack", "enqueue"]
      assert r.layer == :runtime
      assert S.receipt_intact?(r)
    end

    test "realization is deterministic (byte-identical replay)" do
      assert S.realize(admitted!(), work(), 3) == S.realize(admitted!(), work(), 3)
    end

    test "tampering with any realization field breaks the receipt digest" do
      {:ok, r} = S.realize(admitted!(), work(), 1)
      refute S.receipt_intact?(%{r | grants_do_authority: true})
      refute S.receipt_intact?(%{r | authority: "DO"})
      refute S.receipt_intact?(Map.delete(r, :receipt_digest))
    end

    test "work order schema drift and non-admitted input are refused" do
      assert {:error, :consequence_schema_drift} =
               S.realize(admitted!(), work(%{consequence_schema_digest: @d9}), 1)

      assert {:error, :receipt_schema_drift} =
               S.realize(admitted!(), work(%{receipt_schema_digest: @d9}), 1)

      assert {:error, :sequence_invalid} = S.realize(admitted!(), work(), 0)
      assert {:error, :not_admitted} = S.realize(manifest(), work(), 1)
    end
  end

  describe "provider-neutral substitution (DoD 3, 5)" do
    defp second_admitted do
      q = qual(%{receipt_digest: @d5, replay_digest: @d3})
      impl = passport("provider-b", @sha_c, q, %{part_digest: @d9})

      admitted!(
        manifest(%{
          sbb_id: "sbb:queue/provider-b",
          qualification_receipt: q,
          qualification_digest: S.qualification_digest(q),
          implementation: impl
        })
      )
    end

    test "two implementations of one qualified contract conserve semantic identity" do
      a = admitted!()
      b = second_admitted()
      assert {:ok, sub} = S.substitute(a, b, work())
      assert sub.from == "provider-a"
      assert sub.to == "provider-b"
      assert sub.authority == "NONE"
      assert sub.grants_do_authority == false

      {:ok, ra} = S.realize(a, work(), 1)
      {:ok, rb} = S.realize(b, work(), 1)
      assert ra.semantic_digest == rb.semantic_digest
      assert rb.semantic_digest == sub.semantic_digest
      refute ra.receipt_digest == rb.receipt_digest
    end

    test "substitution across different contracts is refused" do
      c2 = contract(%{allowed_behaviors: [:enqueue, :ack]})

      {:ok, b} =
        S.admit(manifest(%{sbb_id: "sbb:x", contract_digest: S.contract_digest(c2)}), abb(), c2)

      assert {:error, :contract_mismatch} = S.substitute(admitted!(), b, work())
    end

    test "self-substitution and kind drift are refused" do
      assert {:error, :substitution_identity} = S.substitute(admitted!(), admitted!(), work())

      q = qual()
      transport = passport("wss", @sha_c, q, %{kind: :transport})
      b = admitted!(manifest(%{sbb_id: "sbb:queue/wss", implementation: transport}))
      assert {:error, :part_kind_mismatch} = S.substitute(admitted!(), b, work())
    end

    test "requested behaviors differing between SBBs is semantic drift" do
      b =
        admitted!(
          manifest(%{
            sbb_id: "sbb:queue/provider-b",
            implementation: passport("provider-b", @sha_c, qual()),
            requested_behaviors: [:enqueue, :dequeue]
          })
        )

      assert {:error, :semantic_identity_drift} = S.substitute(admitted!(), b, work())
    end
  end

  describe "implementation passport admission (DoD 1, 8, 10; xaas#80 court P1-P3)" do
    test "passport with a DO ceiling is refused as authority laundering" do
      impl = passport("provider-a", @sha_b, qual(), %{authority_ceiling: [:do]})

      assert {:error, :do_authority_laundering} =
               S.admit(manifest(%{implementation: impl}), abb(), contract())

      mixed = passport("provider-a", @sha_b, qual(), %{authority_ceiling: [:select, :do]})

      assert {:error, :do_authority_laundering} =
               S.admit(manifest(%{implementation: mixed}), abb(), contract())
    end

    test "passport ceiling above the contract ceiling is refused" do
      narrow = contract(%{authority_ceiling: [:observe, :select]})
      m = manifest(%{contract_digest: S.contract_digest(narrow), requested_authority: [:select]})
      assert {:error, :implementation_ceiling_exceeds_contract} = S.admit(m, abb(), narrow)
    end

    test "requested authority above the passport ceiling is refused" do
      impl = passport("provider-a", @sha_b, qual(), %{authority_ceiling: [:observe, :select]})

      assert {:error, :authority_exceeds_implementation} =
               S.admit(manifest(%{implementation: impl}), abb(), contract())

      assert {:ok, _} =
               S.admit(
                 manifest(%{implementation: impl, requested_authority: [:select]}),
                 abb(),
                 contract()
               )
    end

    test "branch subject and placeholder passport digests are refused" do
      cases = [
        {%{exact_subject: "o/p@main"}, :part_subject_not_exact},
        {%{part_digest: "sha256:x"}, :part_digest_invalid},
        {%{producer_digest: "y"}, :producer_digest_invalid},
        {%{part_id: " "}, :part_identity_missing},
        {%{kind: :vendor}, :part_kind_invalid}
      ]

      for {o, reason} <- cases do
        impl = passport("provider-a", @sha_b, qual(), o)

        assert {:error, ^reason} = S.admit(manifest(%{implementation: impl}), abb(), contract()),
               inspect(o)
      end
    end

    test "placeholder qualification receipt digests are refused" do
      cases = [
        {%{receipt_digest: "x"}, :qualification_receipt_digest_invalid},
        {%{verifier_evidence_digest: "y"}, :verifier_evidence_digest_invalid},
        {%{replay_digest: "z"}, :qualification_replay_digest_invalid}
      ]

      for {o, reason} <- cases do
        m = manifest(%{qualification_receipt: qual(o)})
        assert {:error, ^reason} = S.admit(m, abb(), contract()), inspect(o)
      end
    end
  end

  describe "ledger: duplicate delivery, reordering, crash/restart replay (DoD 6)" do
    defp realizations(n), do: for(i <- 1..n, do: elem(S.realize(admitted!(), work(), i), 1))
    defp ledger, do: Ledger.new(admitted!(), work())

    defp filled(n) do
      Enum.reduce(realizations(n), ledger(), fn r, l ->
        {:admitted, l} = Ledger.deliver(l, r)
        l
      end)
    end

    test "duplicate delivery is idempotent" do
      [r1] = realizations(1)
      {:admitted, l1} = Ledger.deliver(ledger(), r1)
      assert {:duplicate, ^l1} = Ledger.deliver(l1, r1)
      assert length(Ledger.entries(l1)) == 1
    end

    test "reordering and gaps are refused" do
      [r1, r2, r3] = realizations(3)
      assert {:error, :sequence_gap} = Ledger.deliver(ledger(), r2)
      {:admitted, l} = Ledger.deliver(ledger(), r1)
      {:admitted, l} = Ledger.deliver(l, r2)
      assert {:error, :sequence_gap} = Ledger.deliver(ledger(), r3)
      assert {:admitted, _} = Ledger.deliver(l, r3)
    end

    test "conflicting reuse of a recorded sequence is refused" do
      [r1, r2] = realizations(2)
      {:admitted, l} = Ledger.deliver(ledger(), r1)
      {:admitted, l} = Ledger.deliver(l, r2)
      l = %{l | by_seq: Map.put(l.by_seq, 1, @d9)}
      assert {:error, :sequence_conflict} = Ledger.deliver(l, r1)
    end

    test "sequence regression below the ledger head is refused" do
      [r1, r2] = realizations(2)
      {:admitted, l} = Ledger.deliver(ledger(), r1)
      {:admitted, l} = Ledger.deliver(l, r2)
      l = %{l | by_seq: Map.delete(l.by_seq, 1)}
      assert {:error, :sequence_regression} = Ledger.deliver(l, r1)
    end

    test "tampered realization is refused at delivery" do
      [r1] = realizations(1)

      assert {:error, :receipt_digest_mismatch} =
               Ledger.deliver(ledger(), %{r1 | authority: "DO"})

      assert {:error, :malformed_input} = Ledger.deliver(ledger(), %{})
      assert {:error, :malformed_input} = Ledger.deliver(:junk, r1)
    end

    test "self-digested forged realization claiming DO is refused (court P4)" do
      [r1] = realizations(1)

      forged =
        r1
        |> Map.delete(:receipt_digest)
        |> Map.merge(%{authority: "DO", grants_do_authority: true, do_route: "none"})

      forged = Map.put(forged, :receipt_digest, S.digest(forged))
      assert S.receipt_intact?(forged)
      assert {:error, :realization_not_bound} = Ledger.deliver(ledger(), forged)
    end

    test "a realization of another WorkOrder or another SBB is refused" do
      {:ok, other_work} = S.realize(admitted!(), work(%{work_order_id: "urn:work:other"}), 1)
      assert {:error, :realization_not_bound} = Ledger.deliver(ledger(), other_work)

      b =
        admitted!(
          manifest(%{
            sbb_id: "sbb:queue/provider-b",
            implementation: passport("provider-b", @sha_c, qual())
          })
        )

      {:ok, other_sbb} = S.realize(b, work(), 1)
      assert {:error, :realization_not_bound} = Ledger.deliver(ledger(), other_sbb)
    end

    test "ledgers of different bindings start from different genesis heads" do
      other = Ledger.new(admitted!(), work(%{work_order_id: "urn:work:other"}))
      assert ledger().head != other.head
      assert ledger().head == Ledger.genesis(admitted!(), work())
    end

    test "crash/restart replay reproduces the exact chain head" do
      l = filled(5)
      persisted = Ledger.entries(l)
      assert {:ok, restored} = Ledger.replay(admitted!(), work(), persisted)
      assert restored.head == l.head
      assert restored.last_seq == 5
      assert {:ok, _} = Ledger.replay(admitted!(), work(), persisted, l.head)
      [r1 | _] = realizations(1)
      assert {:duplicate, _} = Ledger.deliver(restored, r1)
    end

    test "replay refuses reordered, truncated-prefix or tampered entries" do
      [e1, e2, e3] = Ledger.entries(filled(3))
      rp = &Ledger.replay(admitted!(), work(), &1)
      assert {:error, :replay_mismatch} = rp.([e2, e1, e3])
      assert {:error, :replay_mismatch} = rp.([e2, e3])
      assert {:error, :replay_mismatch} = rp.([e1, %{e2 | receipt_digest: @d9}, e3])
      assert {:error, :replay_mismatch} = rp.([e1, %{e2 | chain: @d9}, e3])
      assert {:error, :malformed_input} = rp.([e1, :junk])
      assert {:error, :malformed_input} = Ledger.replay(admitted!(), work(), :junk)
      assert {:ok, %Ledger{head: head}} = rp.([])
      assert head == Ledger.genesis(admitted!(), work())
    end

    test "history rewritten with a recomputed chain is refused (court P5)" do
      [e1, e2, _e3] = Ledger.entries(filled(3))
      evil = "sha256:" <> String.duplicate("e", 64)
      rewritten = [e1, %{e2 | receipt_digest: evil, chain: S.digest({e1.chain, 2, evil})}]
      assert {:error, :replay_mismatch} = Ledger.replay(admitted!(), work(), rewritten)
    end

    test "replay under a different binding is refused" do
      persisted = Ledger.entries(filled(2))
      other = work(%{work_order_id: "urn:work:other"})
      assert {:error, :replay_mismatch} = Ledger.replay(admitted!(), other, persisted)
    end

    test "anchored replay refuses a truncated suffix" do
      l = filled(3)
      [e1, e2, _e3] = Ledger.entries(l)
      assert {:ok, _} = Ledger.replay(admitted!(), work(), [e1, e2])

      assert {:error, :replay_head_mismatch} =
               Ledger.replay(admitted!(), work(), [e1, e2], l.head)
    end
  end

  describe "OCEL projection (DoD 7, 9)" do
    test "realization projects to one OCEL event bound to work, SBB and contract" do
      {:ok, r} = S.realize(admitted!(), work(), 1)
      ocel = S.to_ocel(r)

      assert [
               %{
                 "id" => id,
                 "type" => "sbb.realized",
                 "relationships" => rels,
                 "attributes" => attrs
               }
             ] = ocel["events"]

      assert id == r.receipt_digest
      assert Enum.map(rels, & &1["qualifier"]) == ["realizes", "implemented_by", "bounded_by"]
      assert %{"name" => "authority", "value" => "NONE"} in attrs

      assert Enum.map(ocel["objects"], & &1["id"]) == [
               "urn:work:sbb-1",
               "sbb:queue/provider-a",
               r.contract_digest
             ]

      assert {:ok, _} = Jason.encode(ocel)
    end
  end

  describe "benchmark regression bound" do
    # Deterministic timing gate. Measured 2026-09-26 with
    # `MIX_ENV=test mix run --no-start bench/sbb_realization_bench.exs`
    # (Elixir 1.20.2 / OTP 28.5, Apple Silicon, load avg ~43), medians:
    # admit 24us, realize 10us, deliver_append 19us (recomputes the bound
    # realization), deliver_duplicate 15us, substitute 51us, anchored
    # replay_1000 16267us (~16us/entry, recomputes every receipt).
    # admit+realize+deliver ~= 55us/op; the bounds below are ~9x / ~6x the
    # measured medians so they trip on an algorithmic regression (e.g. an
    # O(n) ledger scan per delivery), not on scheduler noise.
    @ops 2_000
    @bound_us_per_op 500
    @replay_bound_us_per_entry 100

    test "admit + realize + deliver stays under the per-op bound" do
      a = admitted!()
      m = manifest()

      {us, ledger} =
        :timer.tc(fn ->
          Enum.reduce(1..@ops, Ledger.new(a, work()), fn i, l ->
            {:ok, _} = S.admit(m, abb(), contract())
            {:ok, r} = S.realize(a, work(), i)
            {:admitted, l} = Ledger.deliver(l, r)
            l
          end)
        end)

      assert ledger.last_seq == @ops
      assert us / @ops < @bound_us_per_op, "#{us / @ops} us/op exceeds #{@bound_us_per_op}"

      {replay_us, {:ok, restored}} =
        :timer.tc(fn -> Ledger.replay(a, work(), Ledger.entries(ledger), ledger.head) end)

      assert restored.head == ledger.head
      assert replay_us / @ops < @replay_bound_us_per_entry
    end
  end
end
