defmodule Xaas.Witness.FamilyCourtW984gbTest do
  @moduledoc """
  Lane W984gb unclaimed-family court over `lib/xaas/witness/`.

  Dispositions (see docs/sjira/v26.10.6/plans/w984gb-probe.md):

    * `Xaas.Witness.Catalog.ingest/1` raise path "baseline is missing
      subject_commit" — uncovered by every existing test (the ArgumentError
      in catalog_test.exs:96 is the *action-surface* raise, not this one).
      Courted here, both map mode and path mode.
    * `Xaas.Witness.AuditChain.sig_rejects?/1` fallback clause (sig neither
      nil nor a 1-arity function) — uncovered; courted here.
    * `Catalog` internal refusals `{:ingest_refused, _, _}` and
      `{:key_registration_refused, _, _}` — uncovered but unreachable
      without fault injection (every in-process create-failure route
      resolves to the idempotent branch), so NOT courted — no mocks.
  """

  use ExUnit.Case, async: true

  alias Xaas.Witness.AuditChain
  alias Xaas.Witness.Catalog
  alias Xaas.Witness.CertifiedReceipt
  alias Xaas.Witness.VerificationKey

  @baseline_path Path.join(__DIR__, "fixtures/BASELINE.json")
  @kat_path Path.join(__DIR__, "fixtures/crypto_trust_kat.json")

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Xaas.Repo.delete_all(CertifiedReceipt)
    Xaas.Repo.delete_all(VerificationKey)
    :ok
  end

  defp signing_surface do
    @kat_path |> File.read!() |> Jason.decode!() |> Map.fetch!("corpus")
  end

  # ------------------------------------------------------------------
  # Catalog.ingest/1 — missing subject_commit raise (map mode)
  # Mutation rationale: deleting the `raise ArgumentError` clause in
  # Catalog.ingest/1 would make this ingest return {:ok, ...} with a nil
  # subject (or crash later in string interpolation) instead of refusing
  # at the boundary; the refusal IS the contract.
  # ------------------------------------------------------------------
  test "ingest refuses a baseline map with no subject_commit" do
    assert_raise ArgumentError, ~r/missing subject_commit/, fn ->
      Catalog.ingest(baseline: %{"subject_commit" => nil}, signing_surface: [])
    end
  end

  # ------------------------------------------------------------------
  # Catalog.ingest/1 — missing subject_commit raise (path mode)
  # Path mode decodes the file lazily via fetch_baseline/1; the same
  # contract must hold when the baseline arrives as a file path.
  # ------------------------------------------------------------------
  test "ingest refuses a baseline file whose JSON lacks subject_commit" do
    path = Path.join(System.tmp_dir!(), "w984gb-baseline-no-subject.json")
    File.write!(path, Jason.encode!(%{"mutations" => []}))

    on_exit(fn -> File.rm(path) end)

    assert_raise ArgumentError, ~r/missing subject_commit/, fn ->
      Catalog.ingest(baseline: path, signing_surface: [])
    end
  end

  # ------------------------------------------------------------------
  # AuditChain.sig_rejects?/1 fallback clause.
  # Mutation rationale: deleting `defp sig_rejects?(_), do: false` makes
  # verify_chain/2 raise FunctionClauseError on a malformed sig instead of
  # degrading to documented unsigned mode; this clause is the crash
  # firewall between corrupt sig slots and the verifier.
  # ------------------------------------------------------------------
  test "verify_chain treats a malformed (non-function, non-nil) sig as unsigned" do
    {:ok, chain, _head} =
      AuditChain.append([], %{
        actuation_id: "w984gb-sig-fallback",
        payload_digest: String.duplicate("a", 64),
        sig: :corrupted_sig_slot
      })

    assert :ok = AuditChain.verify_chain(chain)

    # Same degradation on the martingale observable: valid receipt => 1.
    assert [1] = AuditChain.martingale(chain)
  end
end
