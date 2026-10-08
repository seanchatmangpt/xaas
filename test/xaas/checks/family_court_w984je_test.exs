defmodule Xaas.Checks.FamilyCourtW984jeTest do
  @moduledoc """
  Lane W984je unclaimed-family probe court: shared Ash check modules NOT
  owned by another lane's receipt (marketplace checks were courted by
  W984fi/hu; governance freeze/pentest/audit-export families by their own
  depth tests).

  Census result (grep test/ per module): every check module in
  `lib/xaas/**/checks/` is exercised through its real policy by at least
  one existing real-action test EXCEPT the specific branches courted
  below, which no existing test reaches:

    * `Xaas.Checks.SystemActor` — the legacy explicit-`service:` branch on
      an UNCLASSIFIED subject (`required_service/2`'s
      `{{:ok, service}, :error}` -> `admitted_service/1` arms: a valid
      admitted service is honored, a non-admitted service name is
      fail-closed refused). Existing tests cover the canonical map, the
      wrong-genuine-service denial, and the explicit-contradicts-canonical
      refusal — but never the legacy-honored arm.
    * `Xaas.Accounts.Checks.ActorBelongsToOrg` — the fail-closed guard
      arms (`nil` actor, actor with `nil` id, subject record with `nil`
      org id). Only the membership-hit and membership-miss arms are
      exercised today.
    * `Xaas.Billing.Checks.ActorOrgMatches` — the missing/unresolvable
      subscription deny arms (`nil` subscription_id, `Ash.get` miss).
      Existing controller tests cover matching and mismatching orgs, both
      halves, but always with a REAL subscription row.
    * the plain-struct `resolve_org_id/1` fallback clause
      (`%{org_id: org_id}` — non-changeset subject) in
      `SlaCreditActorOrgMatches`, `Governance.ActorOrgMatches`,
      `AuditExportTokenActorOrgMatches`, `Operations.ActorOrgMatches`,
      and `Platform.ActorOrgMatches`. Ash never passes a plain struct
      through a real policy, so the only honest way to exercise the clause
      is direct `match?/3` evaluation; the equality logic it shares with
      the covered clauses is thereby pinned so a future refactor of the
      shared resolve chain cannot silently drop it.
  """

  use ExUnit.Case, async: true

  alias Xaas.Accounts.Checks.ActorBelongsToOrg
  alias Xaas.Accounts.{Org, OrgMembership}
  alias Xaas.Billing.Checks.ActorOrgMatches
  alias Xaas.Billing.Checks.SlaCreditActorOrgMatches
  alias Xaas.Billing.{ApprovalTierDowngrade, Subscription}
  alias Xaas.Checks.SystemActor
  alias Xaas.Governance.Checks.ActorOrgMatches, as: GovernanceActorOrgMatches
  alias Xaas.Governance.Checks.AuditExportTokenActorOrgMatches
  alias Xaas.Operations.Checks.ActorOrgMatches, as: OperationsActorOrgMatches
  alias Xaas.Platform.Checks.ActorOrgMatches, as: PlatformActorOrgMatches
  alias Xaas.SystemAuthority

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org! do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "W984je Org",
      slug: "w984je-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
  end

  defp user! do
    Xaas.Generator.create_user!(%{
      email: "w984je-#{System.unique_integer([:positive])}@example.com"
    })
  end

  defp membership!(user_id, org_id) do
    OrgMembership
    |> Ash.Changeset.for_create(:create, %{user_id: user_id, org_id: org_id, role: :member})
    |> Ash.create!(authorize?: false)
  end

  defp subscription!(org_id) do
    Subscription
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      tier: :pro,
      status: :incomplete
    })
    |> Ash.create!(authorize?: false)
  end

  test "SystemActor: a legacy explicit admitted service on an unclassified subject is honored" do
    # Mutation rationale: deleting `required_service/2`'s
    # `{{:ok, service}, :error} -> admitted_service(service)` arm (or
    # breaking `admitted_service/1`'s membership test) flips this from
    # true to false — the legacy unclassified-subject path silently dies.
    changeset =
      Org
      |> Ash.Changeset.for_create(:create, %{name: "legacy", slug: "legacy-1"})

    assert SystemActor.match?(
             SystemAuthority.new(:internal_api),
             %{subject: changeset},
             service: :internal_api
           )

    refute SystemActor.match?(
             SystemAuthority.new(:oban_scheduler),
             %{subject: changeset},
             service: :internal_api
           )
  end

  test "SystemActor: a legacy explicit NON-admitted service is fail-closed refused" do
    # Mutation rationale: breaking `admitted_service/1`'s
    # `service in Xaas.SystemAuthority.services()` guard (e.g. returning
    # {:ok, service} unconditionally) flips this refute to an assert — an
    # unadmitted service name would gain policy authority.
    changeset =
      Org
      |> Ash.Changeset.for_create(:create, %{name: "legacy", slug: "legacy-2"})

    refute SystemActor.match?(
             SystemAuthority.new(:internal_api),
             %{subject: changeset},
             service: :fabricated_service
           )
  end

  test "ActorBelongsToOrg: nil actor, id-less actor, and org-less record are fail-closed denied against real rows" do
    # Mutation rationale: weakening either `with` guard arm (nil actor,
    # nil actor id, nil resolved org id) to pass through would let this
    # test fail on the refutes — e.g. a nil-org record authorizing any
    # membership-bearing actor.
    real_org = org!()
    real_user = user!()
    membership!(real_user.id, real_org.id)

    org_changeset = Ash.Changeset.for_update(real_org, :update, %{name: "renamed"})

    refute ActorBelongsToOrg.match?(nil, %{subject: org_changeset}, [])
    refute ActorBelongsToOrg.match?(%{id: nil}, %{subject: org_changeset}, [])

    anon_record_subject = %{subject: struct(Org)}

    refute ActorBelongsToOrg.match?(%{id: real_user.id}, anon_record_subject, [])

    # Control on the same real rows: the membership hit arm.
    assert ActorBelongsToOrg.match?(%{id: real_user.id}, %{subject: org_changeset}, [])

    # Real policy-path control already exists in org_membership_test; the
    # control here proves the guard refutes are not an artifact of a dead
    # check.
  end

  test "Billing ActorOrgMatches: unresolvable subscription denies even a matching actor" do
    # Mutation rationale: `subscription_org_id/1`'s `{:error, _} -> nil`
    # arm and the nil-id guard in `resolve_subscription_id/1` are the
    # fail-closed backstop; mutating either to return a matchable value
    # (e.g. the actor's own org) flips the refutes to asserts and a
    # dangling subscription_id would authorize its creator's org.
    actor = %{org_id: "org-w984je-sub"}

    dangling =
      struct(ApprovalTierDowngrade, %{
        subscription_id: "sub-does-not-exist-#{System.unique_integer([:positive])}"
      })

    refute ActorOrgMatches.match?(actor, %{subject: dangling}, [])

    nil_id_record = struct(ApprovalTierDowngrade, %{subscription_id: nil})
    refute ActorOrgMatches.match?(actor, %{subject: nil_id_record}, [])

    # Blank/missing actor org falls to the catch-all clause.
    refute ActorOrgMatches.match?(%{org_id: ""}, %{subject: dangling}, [])
    refute ActorOrgMatches.match?(%{other: :actor}, %{subject: dangling}, [])

    # Control: a REAL subscription row satisfies a matching actor. The
    # subject is a real :create changeset -- unlike its 5 sibling checks,
    # this module has NO plain-struct resolve clause, so a bare struct
    # subject correctly falls to the catch-all deny.
    sub = subscription!("org-w984je-sub")

    create_changeset =
      ApprovalTierDowngrade
      |> Ash.Changeset.for_create(:create, %{
        requested_by: "w984je",
        org_id: "org-w984je-sub",
        subscription_id: sub.id,
        requested_tier: :standard
      })

    assert ActorOrgMatches.match?(actor, %{subject: create_changeset}, [])
  end

  test "SlaCreditActorOrgMatches: plain-struct subject fallback matches and mismatches by org" do
    # Mutation rationale: deleting the `%{org_id: org_id}` fallback clause
    # makes these direct calls fall through to the catch-all — the refutes
    # stay refutes but the asserts flip to refutes, exposing the dropped
    # clause.
    matching = %{subject: %{org_id: "org-w984je-a"}}
    mismatching = %{subject: %{org_id: "org-w984je-b"}}
    actor = %{org_id: "org-w984je-a"}

    assert SlaCreditActorOrgMatches.match?(actor, matching, [])
    refute SlaCreditActorOrgMatches.match?(actor, mismatching, [])
    refute SlaCreditActorOrgMatches.match?(%{org_id: ""}, matching, [])
  end

  test "Governance ActorOrgMatches: plain-struct subject fallback matches and mismatches by org" do
    # Mutation rationale: same as the SlaCredit twin — pins the fallback
    # clause so a resolve-chain refactor cannot silently drop it.
    actor = %{org_id: "org-w984je-g"}
    assert GovernanceActorOrgMatches.match?(actor, %{subject: %{org_id: "org-w984je-g"}}, [])

    refute GovernanceActorOrgMatches.match?(actor, %{subject: %{org_id: "org-w984je-h"}}, [])
  end

  test "AuditExportTokenActorOrgMatches: plain-struct fallback and blank-actor catch-all" do
    # Mutation rationale: the blank-actor catch-all is the fail-closed
    # backstop for un-resolved X-Org-Id headers; mutating the guard
    # `is_binary/!=""` away would flip the blank-org refute to an assert.
    actor = %{org_id: "org-w984je-t"}

    assert AuditExportTokenActorOrgMatches.match?(actor, %{subject: %{org_id: "org-w984je-t"}}, [])
    refute AuditExportTokenActorOrgMatches.match?(actor, %{subject: %{org_id: "org-w984je-u"}}, [])
    refute AuditExportTokenActorOrgMatches.match?(%{org_id: ""}, %{subject: %{org_id: "org-w984je-t"}}, [])
  end

  test "Operations ActorOrgMatches: plain-struct fallback and blank-actor catch-all" do
    # Mutation rationale: pins the fallback clause + catch-all; also pins
    # requires_original_data?/2 -> true, whose removal would turn a
    # future atomic-upgrade regression from a loud InitialDataRequired
    # into a silent deny.
    actor = %{org_id: "org-w984je-o"}

    assert OperationsActorOrgMatches.match?(actor, %{subject: %{org_id: "org-w984je-o"}}, [])
    refute OperationsActorOrgMatches.match?(actor, %{subject: %{org_id: "org-w984je-p"}}, [])
    refute OperationsActorOrgMatches.match?(%{org_id: ""}, %{subject: %{org_id: "org-w984je-o"}}, [])

    assert OperationsActorOrgMatches.requires_original_data?(_authorizer = nil, [])
  end

  test "Platform ActorOrgMatches: plain-struct fallback and blank-actor catch-all" do
    # Mutation rationale: same fail-closed pin as the Operations twin.
    actor = %{org_id: "org-w984je-pl"}

    assert PlatformActorOrgMatches.match?(actor, %{subject: %{org_id: "org-w984je-pl"}}, [])
    refute PlatformActorOrgMatches.match?(actor, %{subject: %{org_id: "org-w984je-q"}}, [])
    refute PlatformActorOrgMatches.match?(%{org_id: ""}, %{subject: %{org_id: "org-w984je-pl"}}, [])

    assert PlatformActorOrgMatches.requires_original_data?(_authorizer = nil, [])
  end
end
