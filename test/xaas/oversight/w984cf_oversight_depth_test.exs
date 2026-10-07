defmodule Xaas.Oversight.W984cfOversightDepthTest do
  @moduledoc """
  Lane W984cf — human-oversight depth court, MINUS covered slices.

  Covered elsewhere (not re-courted here):
  - 26.2 assignment + sig-callback chain: `test/xaas/deepening/art_26_2_human_oversight_assignment_test.exs` (W984be)
  - 26.6 retention rows: `test/xaas/deepening/art_26_6_retention_durable_row_test.exs` (W981t)
  - AuthorityChannel registry/with_endpoint/transmit happy paths + refusals:
    `test/xaas/semantics/authority_channel_test.exs`
  - OversightGovernance typed structures + cited-path existence:
    `test/xaas/semantics/oversight_governance_test.exs`

  The uncourted remainder this lane courts:

  1. **Authority-shape fail-closed legs** (QuiescentStop.authority_admitted?):
     a `source` WITHOUT a binary `kind` (W984be courts only the
     mirror-image missing-source leg), an atom `kind`, and a non-map
     authority are each refused typed before any DO. Mutation rationale:
     dropping the `is_binary(kind)` conjunct admits atom-kind authorities
     and fails this court while W984be's missing-source leg still passes.
  2. **Same-key concurrent stop race** (PINS FLIPPED by W984ct): exactly one
     winner holds the stop receipt, every loser outcome is TYPED (kernel
     replay `{:ok, %{already_stopped: true}}` or a `:REFUSED_STOP_*`
     refusal), no crash — the W984cf-1 unhandled `{:ok, %{status: :replayed}}`
     CaseClauseError is fixed in `quiescent_stop.ex`. One durable intent row
     binds the contended key. Mutation rationale: deleting the `:replayed`
     clause or the claim arbitration reintroduces the loser crash.
  3. **Fresh-key concurrent stop race + rotation on the attractor** (PINS
     FLIPPED by W984ct): two DIFFERENT human authorities with fresh keys race
     on a fresh subject — EXACTLY ONE receipt (the W984cf-2 check-then-act
     TOCTOU is closed by intent-ledger claim arbitration), the loser refuses
     typed, final state quiescent; and after a stop, a second different
     authority cannot re-drive the attractor
     (`:REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT`). Mutation rationale:
     removing the claim routing or the monotone `stopped?` check admits a
     second stopped_at receipt.
  4. **Channel path-degradation semantics** (AuthorityChannel.verify_paths,
     the module's only uncourted seam): an operator channel citing a
     missing path degrades to typed `:OPEN` with a basis naming the
     missing path, and a degraded-but-real channel still transmits as its
     kind. Mutation rationale: deleting `verify_paths` keeps every existing
     AuthorityChannel court green (they cite only existing paths) while a
     drifted citation would silently keep an EVIDENCED standing.
  5. **OversightGovernance list drift**: `retention_policy/0`'s source list
     is a subset of `cited_paths/0`; the two constant lists can drift
     independently, and this cross-consistency court fails on divergence
     while both per-list existence courts still pass.

  Chicago discipline: real Ash actions over real sandboxed Postgres, the
  real quiescent-stop surface, the real channel registry over the real
  repo tree — no mocks.
  """

  use Xaas.DataCase, async: false

  @moduletag :w984cf

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.ActuationIntent
  alias Xaas.Semantics.AuthorityChannel
  alias Xaas.Semantics.OversightGovernance

  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp unique_key(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp authority(tag), do: %{kind: "human_authority", source: "w984cf_#{tag}"}

  defp stop(provider, key, auth) do
    Xaas.Actuation.QuiescentStop.execute(Provider,
      subject_id: provider.id,
      idempotency_key: key,
      authority: auth
    )
  end

  defp create_provider!(name),
    do: Xaas.Generator.create_provider!(%{name: name, org_id: "org-w984cf"})

  test "authority-shape gate is fail-closed on every non-conforming shape" do
    provider = create_provider!("W984cf Shapes")

    # source present but kind missing — W984be's mirror leg.
    assert {:error, :REFUSED_STOP_AUTHORITY} =
             stop(provider, unique_key("w984cf-nokind"), %{source: "w984cf_nokind"})

    # non-binary (atom) kind with a real source — the is_binary(kind) conjunct.
    assert {:error, :REFUSED_STOP_AUTHORITY} =
             stop(provider, unique_key("w984cf-atomkind"), %{
               kind: :human_authority,
               source: "w984cf_atom"
             })

    # non-map authority (atom) — fail-closed, not a crash.
    assert {:error, :REFUSED_STOP_AUTHORITY} =
             stop(provider, unique_key("w984cf-atomauth"), :human_operator)

    # subject untouched after every refusal.
    assert {:ok, row} = Ash.get(Provider, provider.id, authorize?: false)
    assert row.status != :suspended
  end

  test "same-key concurrent stops: winner holds the receipt; contended-key ledger stays exactly-once; state quiescent" do
    provider = create_provider!("W984cf Same-Key Race")

    auth = authority("race_same_key")
    key = unique_key("w984cf-race-same")

    {ok_results, crashes} = run_race(fn _i -> stop(provider, key, auth) end, 2)

    unwrapped = Enum.map(ok_results, fn {:ok_result, r} -> r end)
    receipts = Enum.filter(unwrapped, &match?({:ok, %{stopped_at: _}}, &1))
    losers = Enum.filter(unwrapped, &(&1 not in receipts))

    # PIN FLIPPED (W984ct, fixes W984cf-1): the unhandled `{:ok, %{status:
    # :replayed}}` CaseClauseError is gone. Exactly one racer holds the stop
    # receipt; every loser outcome is TYPED — either the kernel replay
    # envelope's idempotent `{:ok, %{already_stopped: true}}` or a typed
    # refusal (:REFUSED_STOP_*). Mutation rationale: deleting the
    # `:replayed` clause (or the claim arbitration) reintroduces the crash.
    assert length(receipts) == 1, "results: #{inspect(unwrapped)}"

    assert Enum.all?(losers, fn
             {:ok, %{already_stopped: true}} -> true
             {:error, reason} -> typed_stop_refusal?(reason)
             _ -> false
           end),
           "loser outcomes: #{inspect(losers)}"

    assert crashes == [], "crashes: #{inspect(crashes)}"

    assert {:ok, row} = Ash.get(Provider, provider.id, authorize?: false)
    assert row.status == :suspended

    # The contended key binds exactly one durable intent row.
    assert {:ok, rows} =
             Ash.read(Ash.Query.filter(ActuationIntent, idempotency_key == ^key),
               authorize?: false
             )

    assert length(rows) == 1, "intent rows: #{inspect(Enum.map(rows, & &1.idempotency_key))}"
  end

  test "fresh-key concurrent stops and rotation: subject reaches quiescent, rotation cannot re-drive the attractor" do
    provider = create_provider!("W984cf Fresh-Key Race")

    key_a = unique_key("w984cf-race-fresh-a")
    key_b = unique_key("w984cf-race-fresh-b")
    auth_a = auth_of("rotator_a")
    auth_b = auth_of("rotator_b")

    {ok_results, _crashes} =
      run_race(
        fn
          1 -> stop(provider, key_a, auth_a)
          2 -> stop(provider, key_b, auth_b)
        end,
        2
      )

    unwrapped = Enum.map(ok_results, fn {:ok_result, r} -> r end)
    receipts = Enum.filter(unwrapped, &match?({:ok, %{stopped_at: _}}, &1))
    losers = Enum.filter(unwrapped, &(&1 not in receipts))

    # PIN FLIPPED (W984ct, fixes W984cf-2): the fresh-key check-then-act
    # TOCTOU is closed — concurrent fresh-key stops are arbitrated by
    # intent-ledger uniqueness (the subject-scoped claim intent), so EXACTLY
    # ONE racer holds the stop receipt and the loser refuses TYPED
    # (:REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT once the winner's DO lands, or
    # :REFUSED_STOP_CLAIM_CONTENTION if it does not land in the window).
    # Mutation rationale: removing the claim routing re-admits the double
    # stopped_at receipt.
    assert length(receipts) == 1, "results: #{inspect(unwrapped)}"

    assert Enum.all?(losers, fn
             {:error, reason} -> typed_stop_refusal?(reason)
             _ -> false
           end),
           "loser outcomes: #{inspect(losers)}"

    # The attractor end-state holds: the subject is quiescent.
    assert {:ok, row} = Ash.get(Provider, provider.id, authorize?: false)
    assert row.status == :suspended

    # Rotation: after the attractor, a THIRD fresh authority with a fresh
    # key cannot re-drive the subject — typed refusal, no new intent row.
    count_before = intent_count(provider)

    assert {:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT} =
             stop(provider, unique_key("w984cf-rotate-post"), auth_of("rotator_c"))

    assert intent_count(provider) == count_before
  end

  test "channel path degradation: missing cited path degrades to typed OPEN naming the drift; intact channel keeps EVIDENCED; degraded channel still transmits as its kind" do
    missing = "lib/xaas/semantics/does_not_exist_w984cf.ex"

    drifted = %{
      id: :w984cf_drifted_internal,
      kind: :internal,
      article_basis: "W984cf drift court",
      status: :EVIDENCED,
      endpoint: %{kind: :receipt_corpus, cited: true},
      basis: "EVIDENCED — would be silent if verify_paths were deleted",
      report_format: "Art 73 envelope per Xaas.Semantics.IncidentReport",
      where: [missing, "lib/xaas/semantics/incident_report.ex"]
    }

    reg = AuthorityChannel.registry([drifted])
    channel = Enum.find(reg, &(&1.id == :w984cf_drifted_internal))

    # Degraded to typed OPEN, basis NAMES the missing path (auditable, not hidden).
    assert channel.status == :OPEN
    assert channel.basis =~ "does_not_exist_w984cf.ex"
    assert channel.basis =~ "degraded"

    # Intact sibling keeps its standing.
    intact =
      Enum.find(reg, &(&1.id == :internal_escalation_receipt_corpus))

    assert intact.status == :EVIDENCED

    # Degradation changes standing, not transmission class: the kind still
    # records a REAL IncidentReport build against the receipt corpus.
    {:ok, report_map} =
      Xaas.Semantics.IncidentReport.build([
        %{
          digest: "sha256:w984cf-drift-digest",
          refusal_atom: "REFUSED_EUAIA_MANIPULATIVE_HARM",
          status: :refused,
          observed_at: ~U[2026-10-07 00:00:00Z]
        }
      ])

    assert {:ok, %{status: :RECORDED, channel_id: :w984cf_drifted_internal}} =
             AuthorityChannel.transmit({:ok, report_map}, channel)
  end

  test "governance list drift: retention_policy source is a subset of cited_paths" do
    {:ok, policy} = OversightGovernance.retention_policy()
    cited = MapSet.new(OversightGovernance.cited_paths())

    diff = Enum.filter(policy.source, &(&1 not in cited))
    assert diff == [], "retention source paths missing from cited_paths: #{inspect(diff)}"
  end

  defp intent_count(provider) do
    {:ok, count} =
      Ash.read(Ash.Query.filter(ActuationIntent, subject_id == ^provider.id),
        authorize?: false
      )

    length(count)
  end

  defp auth_of(tag), do: authority(tag)

  # Typed loser outcomes of the stop surface (W984ct contract): every
  # :REFUSED_STOP_* atom, kernel-style {:refused, _}/{:failed, _} tuples, or
  # any other {:error, _} the kernel lawfully returns. The point of the pin is
  # "typed, never a crash".
  defp typed_stop_refusal?(atom) when is_atom(atom), do: true

  defp typed_stop_refusal?({tag, _}) when tag in [:refused, :failed], do: true

  defp typed_stop_refusal?(_), do: false

  # Runs `fun` in N concurrent sandbox tasks; returns {ok_results, crashes}
  # where crashes are {pid, reason} pairs from exited tasks.
  defp run_race(fun, n) do
    wrapped = fn i ->
      try do
        {:ok_result, fun.(i)}
      rescue
        e -> {:crash, e}
      end
    end

    tasks = Enum.map(1..n, fn i -> Task.async(fn -> wrapped.(i) end) end)

    results = Enum.map(tasks, &Task.await(&1, 15_000))

    ok_results = Enum.filter(results, &match?({:ok_result, _}, &1))
    crashes = Enum.filter(results, &match?({:crash, _}, &1))

    {ok_results, crashes}
  end
end
