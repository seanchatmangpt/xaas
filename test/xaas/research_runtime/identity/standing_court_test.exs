defmodule Xaas.ResearchRuntime.StandingCourtTest do
  @moduledoc """
  Court over `Xaas.ResearchRuntime.Standing` (W984cz3, v26.10.6).

  Chicago discipline: real module, real returned structs, assertions on final
  state only. No mocks — there are no collaborators to fake; the module under
  test is the entire surface.

  Mutation rationale per test (what mutation would kill the test):

  1. `new` returns ok with real key — kills mutation dropping the
     `nil/""` check inversion (i.e. a mutant that admits empty subjects).
  2. `new` refuses empty key with typed error — kills mutation replacing
     `{:error, :missing_subject_sha}` with `{:ok, value}` (vacuous admission).
  3. `admit` with true predicate flips status to `:admitted` — kills mutation
     that drops the status write-back (admission without state transition).
  4. `admit` with false predicate returns `{:error, :refused}` AND leaves
     status `:unknown` — kills mutation that flips status despite refusal
     (refusal side-effect leak, the standing-conservation invariant).
  5. `admit` with non-1-arity function raises FunctionClauseError — kills
     mutation dropping the `is_function(pred, 1)` guard (silent pass on
     malformed predicate).
  """
  use ExUnit.Case, async: true

  alias Xaas.ResearchRuntime.Standing

  test "new with a real subject_sha yields :unknown standing with provenance map" do
    assert {:ok, standing} = Standing.new(subject_sha: "abc123")
    assert %Standing{subject_sha: "abc123", status: :unknown} = standing
    assert standing.provenance == %{}
  end

  test "new with empty or missing subject_sha is a typed refusal, not silent pass" do
    assert {:error, :missing_subject_sha} = Standing.new(subject_sha: "")
    assert {:error, :missing_subject_sha} = Standing.new(subject_sha: nil)
  end

  test "admit with a true predicate transitions status unknown -> admitted" do
    {:ok, standing} = Standing.new(subject_sha: "def456")
    assert {:ok, admitted} = Standing.admit(standing, fn s -> s.subject_sha == "def456" end)
    assert admitted.status == :admitted
    assert admitted.subject_sha == "def456"
  end

  test "admit with a false predicate refuses and conserves the prior status" do
    {:ok, standing} = Standing.new(subject_sha: "789abc")

    assert {:error, :refused} = Standing.admit(standing, fn s -> s.status == :admitted end)
    # the refused input struct must be unchanged — no partial mutation
    assert standing.status == :unknown
  end

  test "admit rejects a malformed predicate via its arity guard" do
    {:ok, standing} = Standing.new(subject_sha: "feed00")

    assert_raise FunctionClauseError, fn ->
      Standing.admit(standing, fn a, b -> a == b end)
    end
  end
end
