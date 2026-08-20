defmodule Xaas.Operations.CapabilityLivenessRegressionsPropertyTest do
  @moduledoc """
  Real property-based test over `Xaas.Operations.CapabilityLivenessRegressions.detect/1`.

  Substitution disclosure (per `docs/AWS-CHAPTERS-SUBSTITUTION.md`'s precedent
  of naming a substitution explicitly rather than silently swapping it in):
  this codebase has no free/simple mutation-testing tool in its deps (checked
  -- no muzak/mutation_test dep exists in mix.lock). Real property-based/fuzz
  testing via StreamData's `ExUnitProperties` (a real, already-transitive dep
  of `ash`, pinned directly in mix.exs for this test) is the honest substitute:
  it exercises `detect/1` against hundreds of real, randomly generated
  real-database row sequences rather than a fixed set of hand-picked cases,
  which is the property mutation testing would otherwise buy us -- confidence
  that the implementation's actual logic, not just a few examples, is correct.

  Every row is a real `Ash.create!` against the real sandboxed `Xaas.Repo`
  Postgres table (`capability_liveness_receipts`); `detect/1` runs a real
  `Ash.read!` over those real persisted rows. No mocks.
  """
  # async: false, and no {:shared, self()} sandbox mode: this test issues
  # every real Ash.create!/Ash.read! call from a single test process (no
  # spawned collaborator processes need the connection), and Sandbox's
  # shared mode is process-global -- setting it here would race against
  # other async test modules' own shared-mode sandbox checkouts (confirmed
  # real failure: `owner #PID<...> exited` when run alongside
  # capability_liveness_receipt_test.exs, which also uses shared mode).
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Xaas.Operations.CapabilityLivenessReceipt
  alias Xaas.Operations.CapabilityLivenessRegressions

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp status_gen, do: StreamData.member_of(["ALIVE", "UNSUPPORTED", "BUILD_BROKEN"])

  defp pair_gen do
    StreamData.tuple({status_gen(), StreamData.string(:alphanumeric, min_length: 1)})
  end

  property "detect/1 flags a regression for a capability iff its last real ingest is non-ALIVE and the second-to-last is ALIVE" do
    check all(
            pairs <- StreamData.list_of(pair_gen(), min_length: 2, max_length: 8),
            max_runs: 100
          ) do
      capability = "prop.capability.#{System.unique_integer([:positive])}"

      # Real, strictly increasing inserted_at: give each generated pair a
      # unique subject (so the resource's real (capability, subject) upsert
      # identity never collapses two generated entries into one row) and
      # insert them in real sequence order, real Postgres timestamp per
      # real Ash.create! call. A tiny real sleep guarantees Postgres's
      # timestamp resolution actually distinguishes consecutive inserts.
      indexed = Enum.with_index(pairs)

      Enum.each(indexed, fn {{status, subject_suffix}, index} ->
        CapabilityLivenessReceipt
        |> Ash.Changeset.for_create(:ingest, %{
          capability: capability,
          authority: "prop-test",
          status: status,
          executed: true,
          exit_code: if(status == "ALIVE", do: 0, else: 1),
          subject: "#{index}-#{subject_suffix}",
          detail: nil
        })
        |> Ash.create!(authorize?: false)

        Process.sleep(1)
      end)

      [{_last_status, _} | [{second_last_status, _} | _]] = Enum.reverse(indexed) |> Enum.map(&elem(&1, 0))
      {last_status, _} = List.last(pairs)

      expect_regression? = last_status != "ALIVE" and second_last_status == "ALIVE"

      found =
        CapabilityLivenessRegressions.detect()
        |> Enum.filter(&(&1.capability == capability))

      if expect_regression? do
        assert [regression] = found
        assert regression.now.status == last_status
        assert regression.was.status == "ALIVE"
      else
        assert found == []
      end
    end
  end
end
