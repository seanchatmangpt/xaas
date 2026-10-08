defmodule Xaas.Tunnel.SubmitTest do
  @moduledoc """
  W984cw2 depth court for `Xaas.Tunnel.Submit` (W984cj map rank, previously
  uncovered). Chicago-style: real sandboxed Postgres through real Ash actions,
  no owned collaborator replaced.

  Mutation rationale per test (kill these mutants or the test is vacuous):
    * T1 key contract — a mutant that widens `@key` to accept empty/oversized/
      non-[A-Za-z0-9._:-] keys must be killed (it would admit `""` as a
      universal idempotency key colliding every submit in an org);
    * T2 subject binding — a mutant that drops the org slug (or the key) from
      `exact_subject/2` must be killed (keys would leak across orgs);
    * T3 typed refusal — a mutant that turns the invalid-key refusal into a
      raise (or an {:ok, ...} bypass) must be killed;
    * T4 idempotency — a mutant that skips the `(org, subject, cycle 0)` lookup
      (or the advisory lock) must be killed by the replay row being a DIFFERENT
      run; a mutant that flips `replay?` must be killed by the boolean;
    * T5 create surface + typed verifier refusal — a mutant that ignores an
      unknown `verifier_suite` (validation dropped from `:submit`) must be
      killed by the typed `unknown_verifier_suite` error and zero rows.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Accounts.Org
  alias Xaas.Tunnel.Submit
  alias Xaas.Ultracode.{Epoch, Run}

  setup do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    slug = "submit-court-#{System.unique_integer([:positive])}"

    {:ok, org} =
      Org
      |> Ash.Changeset.for_create(:create, %{name: slug, slug: slug}, authorize?: false)
      |> Ash.create()

    %{org: org}
  end

  test "T1 key contract: the idempotency-key regex is the whole contract", %{org: _org} do
    # Legal: 1..128 chars of [A-Za-z0-9._:-].
    assert Submit.valid_key?("k")
    assert Submit.valid_key?("run-2026.10:07_alpha")
    assert Submit.valid_key?(String.duplicate("a", 128))

    # Illegal: empty, >128, non-binary, and any character outside the class
    # (space, slash, unicode) -- the class is also the injection surface.
    refute Submit.valid_key?("")
    refute Submit.valid_key?(String.duplicate("a", 129))
    refute Submit.valid_key?(nil)
    refute Submit.valid_key?(42)
    refute Submit.valid_key?("has space")
    refute Submit.valid_key?("has/slash")
    refute Submit.valid_key?("emoji-🔑")
  end

  test "T2 subject binding: exact_subject is namespaced by org slug and key", %{org: org} do
    assert Submit.exact_subject(org, "k1") == "fabric:#{org.slug}:k1"

    # A different org with the SAME key binds a different subject -- the
    # cross-org collision the fabric:<slug>:<key> prefix exists to prevent.
    {:ok, other} =
      Org
      |> Ash.Changeset.for_create(:create, %{name: "other-org", slug: "other-org"},
        authorize?: false
      )
      |> Ash.create()

    refute Submit.exact_subject(other, "k1") == Submit.exact_subject(org, "k1")

    # The non-idempotent default subject derives from the Run id.
    run = %Run{id: "r-123"}
    assert Submit.default_exact_subject(org, run) == "org:#{org.slug}-run:r-123"
  end

  test "T3 typed refusal on malformed payloads: invalid key refuses without side effects", %{
    org: org
  } do
    for bad <- [nil, "", "bad key!", String.duplicate("x", 129)] do
      assert Submit.submit(org, %{"idempotency_key" => bad}) ==
               {:error, :idempotency_key_required}
    end

    # Refusal happens BEFORE any transaction: no Run and no Epoch leaked.
    assert Ash.count!(Run, tenant: org.id, authorize?: false) == 0
    assert Ash.count!(Epoch, tenant: org.id, authorize?: false) == 0
  end

  test "T4 idempotency: same key replays the same Run/Epoch; new key creates fresh", %{
    org: org
  } do
    params = %{"idempotency_key" => "alpha-1", "goal" => "court the submit surface"}

    {:ok, first} = Submit.submit(org, params)
    assert first.replay? == false
    assert first.run.goal == "court the submit surface"
    # Cycle 0, state :running, org denormalized from the Run -- the fabric
    # claim_next visibility contract.
    assert first.epoch.cycle == 0
    assert first.epoch.state == :running
    assert first.epoch.org_id == first.run.org_id
    assert first.epoch.exact_subject == "fabric:#{org.slug}:alpha-1"

    {:ok, replay} = Submit.submit(org, params)
    assert replay.replay? == true
    assert replay.run.id == first.run.id
    assert replay.epoch.id == first.epoch.id

    # Exactly one Run and one Epoch despite the double submit.
    assert Ash.count!(Run, tenant: org.id, authorize?: false) == 1
    assert Ash.count!(Epoch, tenant: org.id, authorize?: false) == 1

    # A different key under the same org is a different submission.
    {:ok, second} = Submit.submit(org, %{"idempotency_key" => "beta-2", "goal" => "g2"})
    assert second.replay? == false
    refute second.run.id == first.run.id
    assert Ash.count!(Run, tenant: org.id, authorize?: false) == 2
  end

  test "T5 create surface: running epoch on default subject; unknown verifier suite refuses typed", %{
    org: org
  } do
    {:ok, {run, epoch}} = Submit.create(org, %{"goal" => "non-idempotent path"})
    assert run.goal == "non-idempotent path"
    assert run.provider == "zcode"
    assert epoch.cycle == 0 and epoch.state == :running
    assert epoch.exact_subject == Submit.default_exact_subject(org, run)

    # Unknown verifier suite name is a typed refusal, and the transaction
    # rolls back so NO Run or Epoch survives the failed create.
    {:error, reason} =
      Submit.create(org, %{"goal" => "g", "verifier_suite" => "never-registered-suite"})

    assert inspect(reason) =~ "unknown_verifier_suite"

    assert Ash.count!(Run, tenant: org.id, authorize?: false) == 1
    assert Ash.count!(Epoch, tenant: org.id, authorize?: false) == 1
  end
end
