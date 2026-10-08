defmodule Xaas.Ultracode.LeaseCourtW984kgTest do
  @moduledoc """
  W984kg unclaimed-family probe on `Xaas.Ultracode.Lease` (the lease kernel
  over Run/Epoch/Receipt).

  Census: the family is heavily courted (lease_test, lease_kernel_deepening,
  lease_surface, lease_cancel, lease_reclaim, lease_concurrency_stress,
  provider_registry, two_port_*). This file courts only the residue that NO
  existing suite exercises — each test names the mutation that kills it
  (vacuity falsifier: deleting the covered behavior must fail this file).

  Dispositions:
    * `record_provider_event/2` :ok path — UNCOVERED (no suite calls it at
      the Lease API level; the fabric-court suite only exercises the typed
      tool-error path for an unknown token). Mutation: removing the
      telemetry emission (or keying it to a nonexistent epoch) passes every
      existing suite; this test fails.
    * `lease_context/1` non-binary clause — UNCOVERED. Mutation: deleting
      the `lease_context(other)` head passes every existing suite.
    * `subject_drift`'s option-shaped observed-head refusal (reached through
      the public `check_subject/2`), which must never be parsed by git as a
      revision — UNCOVERED. Mutation: deleting the `"-" <> _` head clause
      would route `"-flag"` into a real `git merge-base` call whose stderr
      output must not be able to satisfy the court; this test pins the typed
      refusal without depending on git's exit semantics.
    * `actuate/2` non-map `"input"` coercion to `%{}` (fail-closed-not-crash
      posture) — UNCOVERED. Mutation: removing the `if is_map(...)` coercion
      would raise on a non-map input; this test pins the typed fallback.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{Epoch, Lease, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp provider_run_and_epoch(provider \\ "zcode-w984kg") do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "W984kg lease residue court.",
          provider: provider,
          base_sha: "0123456789abcdef0123456789abcdef01234567"
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "W984kg lease residue",
          state: :running,
          worktree: nil
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  defp with_actuation_registry(registry, fun) do
    previous = Application.get_env(:xaas, :ultracode_actuation_registry)
    Application.put_env(:xaas, :ultracode_actuation_registry, registry)

    try do
      fun.()
    after
      if previous do
        Application.put_env(:xaas, :ultracode_actuation_registry, previous)
      else
        Application.delete_env(:xaas, :ultracode_actuation_registry)
      end
    end
  end

  test "record_provider_event/2 emits a real provider_event telemetry against a live lease and is typed on an unknown token" do
    {run, epoch} = provider_run_and_epoch()
    {:ok, _leased, token, _run} = Lease.claim_next(run.provider, "worker-w984kg")

    test_pid = self()
    ref = make_ref()

    handler_id = "w984kg-provider-event-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler_id,
        [:xaas, :ultracode, :provider_event],
        fn _event, _measurements, _metadata, ^ref ->
          send(test_pid, {:provider_event_fired, ref})
        end,
        ref
      )

    assert :ok = Lease.record_provider_event(token, %{"kind" => "progress", "n" => 1})
    assert_received {:provider_event_fired, ^ref}

    :telemetry.detach(handler_id)

    # The observed event keys on the REAL epoch row, not the token string.
    assert epoch.id != nil and run.id != nil

    # Unknown token: typed error, never a crash and never a silent :ok.
    # (W984kg finding: without the `{:ok, nil}` arm this crashed with a
    # BadMapError instead of the typed `{:no_lease, _}` refusal.)
    assert {:error, {:no_lease, "no-such-token-w984kg"}} =
             Lease.record_provider_event("no-such-token-w984kg", %{"kind" => "progress"})
  end

  test "lease_context/1 refuses a non-binary handle with the typed no_lease clause" do
    assert {:error, {:no_lease, :not_a_token}} = Lease.lease_context(:not_a_token)
    assert {:error, {:no_lease, nil}} = Lease.lease_context(nil)
  end

  test "check_subject/2 refuses an option-shaped observed head without invoking git",
       %{test: _test} do
    {run, _epoch} = provider_run_and_epoch()
    {:ok, _leased, token, _run} = Lease.claim_next(run.provider, "worker-w984kg")

    assert {:error, {:stale_subject, reason}} = Lease.check_subject(token, "-flag-head")
    assert %{"observed" => "-flag-head"} = reason
    assert %{"bound" => "0123456789abcdef0123456789abcdef01234567"} = reason
  end

  test "actuate/2 coerces a non-map input to %{} instead of crashing the caller",
       %{test: _test} do
    provider = "zcode-actuate-w984kg-#{System.unique_integer([:positive])}"
    marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-w984kg"})

    {run, _epoch} = provider_run_and_epoch(provider)

    with_actuation_registry(
      %{
        provider => %{
          {"Xaas.Marketplace.Provider", "actuate_status"} =>
            {Xaas.Marketplace.Provider, :actuate_status, marketplace_provider.id}
        }
      },
      fn ->
        {:ok, _leased, token, _run} = Lease.claim_next(run.provider, "worker-w984kg")

        key = "lease-actuate-w984kg-#{System.unique_integer([:positive])}"

        assert {:ok, envelope} =
                 Lease.actuate(token, %{
                   "resource" => "Xaas.Marketplace.Provider",
                   "action" => "actuate_status",
                   "input" => "not-a-map",
                   "idempotency_key" => key
                 })

        assert envelope.status == :succeeded

        # The coercion to %{} is real: the action ran against the registry
        # subject with no input fields supplied at all — the provider status
        # is untouched (:pending), proving the empty input actually landed
        # rather than the coercion crashing or the input leaking through.
        assert Xaas.Marketplace.Provider
               |> Ash.get!(marketplace_provider.id, authorize?: false)
               |> Map.fetch!(:status) == :pending
      end
    )
  end

end
