defmodule Xaas.Ultracode.SbbRealization do
  @moduledoc """
  Qualified SBB runtime realization court (RFC v26.9.26 ABB/SBB seed,
  `docs/rfc/v26.9.26/abb-sbb-implementation.md`).

  A Solution Building Block (SBB) manifest is admitted only when it is bound,
  by recomputed content digests, to the exact Architecture Building Block
  (ABB), the exact ArchitectureContract and the exact qualification receipt it
  claims. Admission is SELECT; realization is CONSTRUCT (a bounded plan and a
  receipt). Neither step grants execution authority: every record carries
  `authority: "NONE"` and `grants_do_authority: false`; a manifest requesting
  `:do` is refused with `:do_requires_brce` because consequential DO is routed
  only through BRCE (Lease -> Xaas.Actuation), never through qualification.

  Provider/transport substitution between two admitted SBBs of the same
  qualified contract is delegated to `Xaas.Ultracode.SubstitutionCourt`, and
  the semantic realization identity is conserved across the substitution.

  The implementation `PartPassport` is admitted by the same passport law as
  `SubstitutionCourt` (`SubstitutionCourt.validate_part/1`): exact subject,
  exact content and qualification digests, and an authority ceiling that never
  contains DO (`:do_authority_laundering`). The passport ceiling must also lie
  inside the contract ceiling, and the requested authority inside both.

  `Ledger` gives crash/restart/replay and duplicate-delivery evidence: an
  append-only, hash-chained, strictly sequenced record of realizations for ONE
  admission and ONE WorkOrder (`Ledger.new/2`). A delivered realization is
  admitted only if it is exactly the record `realize/3` produces for that
  binding at that sequence number, so a self-digested forgery (e.g. one that
  claims DO) or a realization of another WorkOrder is refused. Duplicate
  delivery is idempotent; reordering, gaps and sequence reuse are refused.
  `Ledger.replay/3` rebuilds a persisted ledger against its binding and
  recomputes every receipt and chain link, so a tampered, reordered or
  rewritten-with-recomputed-chain history is refused with `:replay_mismatch`.
  A truncated suffix is still a valid prefix; `Ledger.replay/4` with the
  expected head digest refuses that (`:replay_head_mismatch`).
  """

  alias Xaas.Ultracode.SubstitutionCourt
  alias Xaas.Ultracode.SubstitutionCourt.{PartPassport, QualificationReceipt, WorkIdentity}

  @sha256 ~r/^sha256:[0-9a-f]{64}$/
  @subject ~r/^[^\s@]+\/[^\s@]+@[0-9a-f]{40}$/
  @layers [:capability, :resource, :runtime, :delivery, :product, :governance, :intelligence]
  @allowed_authorities MapSet.new([:observe, :select, :construct])
  @max_behaviors 64

  def layers, do: @layers

  defmodule Abb do
    @moduledoc "Architecture Building Block: the stable, technology-neutral capability."
    @enforce_keys [:abb_id, :exact_subject, :layer, :capability]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule ArchitectureContract do
    @moduledoc "Behavior/authority envelope every SBB realization must stay inside."
    @enforce_keys [
      :contract_id,
      :abb_id,
      :exact_subject,
      :allowed_behaviors,
      :authority_ceiling,
      :consequence_schema_digest,
      :receipt_schema_digest
    ]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule Manifest do
    @moduledoc "Qualified SBB manifest: one implementation of an ABB under a contract."
    @enforce_keys [
      :sbb_id,
      :abb_id,
      :abb_digest,
      :contract_subject,
      :contract_digest,
      :qualification_digest,
      :qualification_receipt,
      :implementation,
      :requested_behaviors,
      :requested_authority
    ]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule Admitted do
    @moduledoc "Result of admission; only constructible by `SbbRealization.admit/3`."
    @enforce_keys [:manifest, :abb, :contract, :admission_digest]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  # ---------------------------------------------------------------- digests

  @doc "Canonical content digest (sorted map keys, structs as maps)."
  @spec digest(term()) :: String.t()
  def digest(value) do
    canonical = value |> canonical_term() |> :erlang.term_to_binary()
    "sha256:" <> (:crypto.hash(:sha256, canonical) |> Base.encode16(case: :lower))
  end

  def abb_digest(%Abb{} = abb), do: digest(abb)
  def contract_digest(%ArchitectureContract{} = c), do: digest(c)
  def qualification_digest(%QualificationReceipt{} = q), do: digest(q)

  # -------------------------------------------------------------- admission

  @doc """
  SELECT: admit a qualified SBB manifest against the exact ABB and contract.
  """
  @spec admit(Manifest.t(), Abb.t(), ArchitectureContract.t()) ::
          {:ok, Admitted.t()} | {:error, atom()}
  def admit(%Manifest{} = m, %Abb{} = abb, %ArchitectureContract{} = contract) do
    with :ok <- validate_abb(abb),
         :ok <- validate_contract(contract),
         :ok <- same_abb(m, abb, contract),
         :ok <- digest_eq(m.abb_digest, abb_digest(abb), :abb_digest_mismatch),
         :ok <- fresh_subject(m, contract),
         :ok <- digest_eq(m.contract_digest, contract_digest(contract), :contract_digest_mismatch),
         :ok <- validate_qualification(m),
         :ok <- validate_implementation(m, contract),
         :ok <- validate_authority_request(m.requested_authority, contract),
         :ok <- within_implementation(m, contract),
         :ok <- within_contract(m.requested_behaviors, contract) do
      admission_digest =
        digest(%{
          schema: "xaas.sbb-admission/1",
          sbb_id: m.sbb_id,
          abb_digest: m.abb_digest,
          contract_digest: m.contract_digest,
          qualification_digest: m.qualification_digest,
          implementation_digest: m.implementation.part_digest
        })

      {:ok,
       %Admitted{manifest: m, abb: abb, contract: contract, admission_digest: admission_digest}}
    end
  end

  def admit(_, _, _), do: {:error, :malformed_input}

  # ------------------------------------------------------------ realization

  @doc """
  CONSTRUCT: materialize one bounded runtime realization from an admitted SBB
  for one WorkOrder. `seq` is the delivery sequence number (positive integer).
  """
  @spec realize(Admitted.t(), WorkIdentity.t(), pos_integer()) :: {:ok, map()} | {:error, atom()}
  def realize(%Admitted{} = a, %WorkIdentity{} = work, seq) when is_integer(seq) and seq > 0 do
    c = a.contract

    cond do
      work.consequence_schema_digest != c.consequence_schema_digest ->
        {:error, :consequence_schema_drift}

      work.receipt_schema_digest != c.receipt_schema_digest ->
        {:error, :receipt_schema_drift}

      not valid_subject?(work.exact_subject) ->
        {:error, :work_subject_not_exact}

      true ->
        {:ok, build_realization(a, work, seq)}
    end
  end

  def realize(%Admitted{}, %WorkIdentity{}, _seq), do: {:error, :sequence_invalid}
  def realize(_, _, _), do: {:error, :not_admitted}

  defp build_realization(a, work, seq) do
    m = a.manifest
    work_digest = SubstitutionCourt.work_identity_digest(work)

    semantic = %{
      schema: "xaas.sbb-realization/1",
      work_identity_digest: work_digest,
      abb_digest: m.abb_digest,
      contract_digest: m.contract_digest,
      layer: a.abb.layer,
      behaviors: m.requested_behaviors |> Enum.map(&Atom.to_string/1) |> Enum.sort(),
      consequence_schema_digest: a.contract.consequence_schema_digest,
      receipt_schema_digest: a.contract.receipt_schema_digest
    }

    semantic_digest = digest(semantic)

    topology = %{
      sbb_id: m.sbb_id,
      implementation: m.implementation.part_id,
      implementation_subject: m.implementation.exact_subject,
      implementation_digest: m.implementation.part_digest,
      qualification_digest: m.qualification_digest,
      admission_digest: a.admission_digest
    }

    body =
      Map.merge(semantic, %{
        semantic_digest: semantic_digest,
        work_order_id: work.work_order_id,
        sequence: seq,
        topology: topology,
        authority: "NONE",
        authority_ceiling: canonical_authority(m.requested_authority),
        grants_do_authority: false,
        do_route: "BRCE"
      })

    Map.put(body, :receipt_digest, digest(body))
  end

  # ------------------------------------------------------------ substitution

  @doc """
  Provider-neutral substitution between two admitted SBBs of the same
  qualified ABB + contract. Conserves the semantic realization digest.
  """
  @spec substitute(Admitted.t(), Admitted.t(), WorkIdentity.t()) ::
          {:ok, map()} | {:error, atom()}
  def substitute(%Admitted{} = a, %Admitted{} = b, %WorkIdentity{} = work) do
    cond do
      a.manifest.abb_digest != b.manifest.abb_digest -> {:error, :abb_mismatch}
      a.manifest.contract_digest != b.manifest.contract_digest -> {:error, :contract_mismatch}
      a.manifest.sbb_id == b.manifest.sbb_id -> {:error, :substitution_identity}
      true -> do_substitute(a, b, work)
    end
  end

  def substitute(_, _, _), do: {:error, :not_admitted}

  defp do_substitute(a, b, work) do
    with {:ok, court} <-
           SubstitutionCourt.qualify(work, a.manifest.implementation, b.manifest.implementation),
         {:ok, ra} <- realize(a, work, 1),
         {:ok, rb} <- realize(b, work, 1),
         :ok <- digest_eq(ra.semantic_digest, rb.semantic_digest, :semantic_identity_drift) do
      {:ok,
       %{
         schema: "xaas.sbb-substitution/1",
         substitution_receipt: court.receipt_digest,
         semantic_digest: ra.semantic_digest,
         from: ra.topology.implementation,
         to: rb.topology.implementation,
         authority: "NONE",
         grants_do_authority: false
       }}
    end
  end

  # ------------------------------------------------------------------ OCEL

  @doc "Project a realization to an OCEL 2.0-shaped event/object record."
  @spec to_ocel(map()) :: map()
  def to_ocel(%{schema: "xaas.sbb-realization/1"} = r) do
    %{
      "objectTypes" => [
        %{"name" => "WorkOrder"},
        %{"name" => "SBB"},
        %{"name" => "ArchitectureContract"}
      ],
      "eventTypes" => [%{"name" => "sbb.realized"}],
      "objects" => [
        %{"id" => r.work_order_id, "type" => "WorkOrder"},
        %{"id" => r.topology.sbb_id, "type" => "SBB"},
        %{"id" => r.contract_digest, "type" => "ArchitectureContract"}
      ],
      "events" => [
        %{
          "id" => r.receipt_digest,
          "type" => "sbb.realized",
          "attributes" => [
            %{"name" => "sequence", "value" => r.sequence},
            %{"name" => "semantic_digest", "value" => r.semantic_digest},
            %{"name" => "layer", "value" => Atom.to_string(r.layer)},
            %{"name" => "authority", "value" => r.authority}
          ],
          "relationships" => [
            %{"objectId" => r.work_order_id, "qualifier" => "realizes"},
            %{"objectId" => r.topology.sbb_id, "qualifier" => "implemented_by"},
            %{"objectId" => r.contract_digest, "qualifier" => "bounded_by"}
          ]
        }
      ]
    }
  end

  # ---------------------------------------------------------------- ledger

  defmodule Ledger do
    @moduledoc """
    Append-only, hash-chained, strictly sequenced realization ledger bound to
    one `Admitted` SBB and one `WorkIdentity`. Serializable via `entries/1`;
    `replay/3,4` rebuilds and re-verifies it against the same binding.
    """
    alias Xaas.Ultracode.SbbRealization
    alias Xaas.Ultracode.SbbRealization.Admitted
    alias Xaas.Ultracode.SubstitutionCourt
    alias Xaas.Ultracode.SubstitutionCourt.WorkIdentity

    @enforce_keys [:admitted, :work, :binding_digest, :head]
    defstruct [:admitted, :work, :binding_digest, :head, entries: [], last_seq: 0, by_seq: %{}]

    @doc "A fresh ledger bound to one admission and one WorkOrder."
    def new(%Admitted{} = a, %WorkIdentity{} = work) do
      binding = genesis(a, work)
      %__MODULE__{admitted: a, work: work, binding_digest: binding, head: binding}
    end

    @doc "Genesis head: digest of the (admission, work identity) binding."
    def genesis(%Admitted{} = a, %WorkIdentity{} = work) do
      SbbRealization.digest(
        {"xaas.sbb-ledger/1", a.admission_digest, SubstitutionCourt.work_identity_digest(work)}
      )
    end

    @doc """
    Deliver a realization. Returns `{:admitted, ledger}`, `{:duplicate, ledger}`
    (same receipt redelivered: idempotent, ledger unchanged) or `{:error, reason}`.
    Only the exact record `realize/3` yields for this ledger's binding at that
    sequence is admitted (`:realization_not_bound` otherwise).
    """
    def deliver(%__MODULE__{} = l, %{receipt_digest: rd, sequence: seq} = r) do
      cond do
        not SbbRealization.receipt_intact?(r) -> {:error, :receipt_digest_mismatch}
        expected(l, seq) != {:ok, r} -> {:error, :realization_not_bound}
        Map.get(l.by_seq, seq) == rd -> {:duplicate, l}
        Map.has_key?(l.by_seq, seq) -> {:error, :sequence_conflict}
        seq <= l.last_seq -> {:error, :sequence_regression}
        seq != l.last_seq + 1 -> {:error, :sequence_gap}
        true -> {:admitted, append(l, seq, rd)}
      end
    end

    def deliver(_, _), do: {:error, :malformed_input}

    defp expected(%__MODULE__{admitted: a, work: work}, seq),
      do: SbbRealization.realize(a, work, seq)

    defp append(%__MODULE__{} = l, seq, rd) do
      chain = SbbRealization.digest({l.head, seq, rd})
      entry = %{sequence: seq, receipt_digest: rd, prev: l.head, chain: chain}

      %__MODULE__{
        l
        | entries: [entry | l.entries],
          head: chain,
          last_seq: seq,
          by_seq: Map.put(l.by_seq, seq, rd)
      }
    end

    @doc "Persisted form (oldest first)."
    def entries(%__MODULE__{entries: e}), do: Enum.reverse(e)

    @doc """
    Crash/restart: rebuild from persisted entries against the binding,
    recomputing every receipt (via `realize/3`) and every chain link.
    """
    def replay(%Admitted{} = a, %WorkIdentity{} = work, entries) when is_list(entries) do
      Enum.reduce_while(entries, {:ok, new(a, work)}, fn
        %{sequence: seq, receipt_digest: rd, prev: prev, chain: chain}, {:ok, l}
        when is_integer(seq) ->
          cond do
            prev != l.head -> {:halt, {:error, :replay_mismatch}}
            seq != l.last_seq + 1 -> {:halt, {:error, :replay_mismatch}}
            not receipt_expected?(l, seq, rd) -> {:halt, {:error, :replay_mismatch}}
            SbbRealization.digest({prev, seq, rd}) != chain -> {:halt, {:error, :replay_mismatch}}
            true -> {:cont, {:ok, append(l, seq, rd)}}
          end

        _, _ ->
          {:halt, {:error, :malformed_input}}
      end)
    end

    def replay(_, _, _), do: {:error, :malformed_input}

    @doc "Anchored replay: additionally refuses unless the rebuilt head is `expected_head`."
    def replay(a, work, entries, expected_head) do
      case replay(a, work, entries) do
        {:ok, %__MODULE__{head: ^expected_head} = l} -> {:ok, l}
        {:ok, _} -> {:error, :replay_head_mismatch}
        error -> error
      end
    end

    defp receipt_expected?(l, seq, rd) do
      case expected(l, seq) do
        {:ok, %{receipt_digest: ^rd}} -> true
        _ -> false
      end
    end
  end

  @doc "True when the realization's receipt digest recomputes from its body."
  def receipt_intact?(%{receipt_digest: rd} = r) when is_binary(rd) do
    digest(Map.delete(r, :receipt_digest)) == rd
  end

  def receipt_intact?(_), do: false

  # ------------------------------------------------------------- validators

  defp validate_abb(abb) do
    cond do
      blank?(abb.abb_id) -> {:error, :abb_identity_missing}
      not valid_subject?(abb.exact_subject) -> {:error, :abb_subject_not_exact}
      abb.layer not in @layers -> {:error, :layer_invalid}
      blank?(abb.capability) -> {:error, :abb_capability_missing}
      true -> :ok
    end
  end

  defp validate_contract(c) do
    cond do
      blank?(c.contract_id) -> {:error, :contract_identity_missing}
      not valid_subject?(c.exact_subject) -> {:error, :contract_subject_not_exact}
      not behavior_list?(c.allowed_behaviors) -> {:error, :contract_behaviors_invalid}
      not digest?(c.consequence_schema_digest) -> {:error, :consequence_schema_digest_invalid}
      not digest?(c.receipt_schema_digest) -> {:error, :receipt_schema_digest_invalid}
      true -> validate_ceiling(c.authority_ceiling)
    end
  end

  defp validate_ceiling(list) when is_list(list) do
    set = MapSet.new(list)

    cond do
      length(list) != MapSet.size(set) -> {:error, :authority_ceiling_ambiguous}
      MapSet.member?(set, :do) -> {:error, :do_requires_brce}
      not MapSet.subset?(set, @allowed_authorities) -> {:error, :authority_ceiling_invalid}
      true -> :ok
    end
  end

  defp validate_ceiling(_), do: {:error, :authority_ceiling_invalid}

  defp same_abb(m, abb, c) do
    if m.abb_id == abb.abb_id and c.abb_id == abb.abb_id, do: :ok, else: {:error, :abb_mismatch}
  end

  defp fresh_subject(m, c) do
    cond do
      not valid_subject?(m.contract_subject) -> {:error, :contract_subject_not_exact}
      m.contract_subject != c.exact_subject -> {:error, :stale_contract_subject}
      true -> :ok
    end
  end

  defp validate_qualification(%Manifest{qualification_receipt: %QualificationReceipt{} = q} = m) do
    cond do
      q.passed != true ->
        {:error, :qualification_not_pass}

      not digest?(m.qualification_digest) ->
        {:error, :qualification_digest_invalid}

      m.qualification_digest != qualification_digest(q) ->
        {:error, :qualification_digest_mismatch}

      true ->
        :ok
    end
  end

  defp validate_qualification(_), do: {:error, :qualification_receipt_missing}

  defp validate_implementation(%Manifest{implementation: %PartPassport{} = p} = m, c) do
    with :ok <- SubstitutionCourt.validate_part(p) do
      implementation_within_contract(p, m, c)
    end
  end

  defp validate_implementation(_, _), do: {:error, :implementation_passport_missing}

  defp within_implementation(%Manifest{implementation: p, requested_authority: req}, c) do
    ceiling = MapSet.new(p.authority_ceiling)

    cond do
      not MapSet.subset?(ceiling, MapSet.new(c.authority_ceiling)) ->
        {:error, :implementation_ceiling_exceeds_contract}

      not MapSet.subset?(MapSet.new(req), ceiling) ->
        {:error, :authority_exceeds_implementation}

      true ->
        :ok
    end
  end

  defp implementation_within_contract(p, m, c) do
    cond do
      p.qualification_receipt != m.qualification_receipt ->
        {:error, :qualification_not_bound_to_implementation}

      p.consequence_schema_digest != c.consequence_schema_digest ->
        {:error, :consequence_schema_drift}

      p.receipt_schema_digest != c.receipt_schema_digest ->
        {:error, :receipt_schema_drift}

      true ->
        :ok
    end
  end

  defp validate_authority_request(list, c) when is_list(list) do
    with :ok <- validate_ceiling(list) do
      if MapSet.subset?(MapSet.new(list), MapSet.new(c.authority_ceiling)),
        do: :ok,
        else: {:error, :authority_ceiling_increase}
    end
  end

  defp validate_authority_request(_, _), do: {:error, :authority_ceiling_invalid}

  defp within_contract(behaviors, c) do
    cond do
      not behavior_list?(behaviors) ->
        {:error, :behaviors_invalid}

      behaviors == [] ->
        {:error, :behaviors_empty}

      not MapSet.subset?(MapSet.new(behaviors), MapSet.new(c.allowed_behaviors)) ->
        {:error, :behavior_outside_contract}

      true ->
        :ok
    end
  end

  defp behavior_list?(list) when is_list(list) and length(list) <= @max_behaviors do
    Enum.all?(list, &is_atom/1) and length(list) == length(Enum.uniq(list))
  end

  defp behavior_list?(_), do: false

  defp digest_eq(a, a, _reason) when is_binary(a), do: :ok
  defp digest_eq(_, _, reason), do: {:error, reason}

  defp canonical_authority(list), do: list |> Enum.map(&Atom.to_string/1) |> Enum.sort()
  defp valid_subject?(v), do: is_binary(v) and Regex.match?(@subject, v)
  defp digest?(v), do: is_binary(v) and Regex.match?(@sha256, v)
  defp blank?(v), do: not is_binary(v) or String.trim(v) == ""

  defp canonical_term(v) when is_struct(v), do: v |> Map.from_struct() |> canonical_term()

  defp canonical_term(v) when is_map(v),
    do: v |> Enum.map(fn {k, x} -> {k, canonical_term(x)} end) |> Enum.sort()

  defp canonical_term(v) when is_list(v), do: Enum.map(v, &canonical_term/1)

  defp canonical_term(v) when is_tuple(v),
    do: v |> Tuple.to_list() |> Enum.map(&canonical_term/1) |> List.to_tuple()

  defp canonical_term(v), do: v
end
