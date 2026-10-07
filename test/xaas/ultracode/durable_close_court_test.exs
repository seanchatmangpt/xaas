defmodule Xaas.Ultracode.DurableCloseCourtTest do
  @moduledoc """
  Depth court on `Xaas.Ultracode.DurableClose` (lane W984cy3).

  DurableClose is the lease-fenced Git publication primitive: a candidate
  commit is not durable work until a reachable ref moves to it while the
  epoch lease is still live. The invariants under court:

    * DURABILITY: on the happy path the ref really moves — asserted against
      `git rev-parse HEAD` on disk, not against the return value. `:ok`
      must mean bytes-on-disk, else the primitive is vacuous.
    * FENCE: publication is authorized only by a live lease row
      (`state: :running`, `lease_expires_at` in the future). No row, an
      expired lease, or a non-running state each refuses with a distinct
      `{:lease_lost, reason, commit}` and the ref must NOT move.
    * TYPED REFUSALS: an un-publishable commit (git object missing) refuses
      `{:refuse, :ref_update_failed, detail}` naming the unreferenced
      commit, never `:ok`-shaped and never a crash.

  Mutation rationale (kill-the-mutant criterion per test): kill the mutant
  that (1) returns :ok without running update-ref (test 1), (2) skips the
  lease lookup (test 2), (3) compares expiry against `now` in the wrong
  direction or drops the expiry comparison (test 3), (4) drops the state
  comparison (test 4), or (5) swallows a git failure as :ok (test 5).
  """

  use ExUnit.Case, async: true

  @moduletag :ultracode

  alias Xaas.Ultracode.{DurableClose, Epoch, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "1. happy path: live lease publishes, HEAD really moves on disk" do
    {worktree, c1, _c2} = git_repo!()
    epoch = leased_epoch!()

    assert :ok = DurableClose.publish(epoch.lease_token, worktree, c1, head(worktree))

    # Durability asserted on disk, not from the return value.
    assert head(worktree) == c1
    assert git!(worktree, ["reflog", "-1", "--format=%gs"]) =~ "ultracode: fenced durable close"
  end

  test "2. unknown lease token refuses {:lease_lost, :no_lease, commit}; HEAD does not move" do
    {worktree, c1, c2} = git_repo!()

    assert {:lease_lost, :no_lease, ^c1} = DurableClose.publish("no-such-token", worktree, c1, c2)

    assert head(worktree) == c2
  end

  test "3. expired lease refuses {:lease_lost, :lease_expired, commit}; HEAD does not move" do
    {worktree, c1, c2} = git_repo!()
    epoch = leased_epoch!(expires_in: -60)

    assert {:lease_lost, :lease_expired, ^c1} =
             DurableClose.publish(epoch.lease_token, worktree, c1, c2)

    assert head(worktree) == c2
  end

  test "4. non-running epoch refuses {:lease_lost, {:lease_not_live, :completed}, commit}" do
    {worktree, c1, c2} = git_repo!()
    epoch = leased_epoch!()

    # Leave :running through the epoch's lawful completion action.
    epoch =
      epoch
      |> Ash.Changeset.for_update(:complete, %{}, authorize?: false)
      |> Ash.update!()

    assert {:lease_lost, {:lease_not_live, :completed}, ^c1} =
             DurableClose.publish(epoch.lease_token, worktree, c1, c2)

    assert head(worktree) == c2
  end

  test "5. ref-update failure refuses typed {:refuse, :ref_update_failed, detail}" do
    {worktree, _c1, c2} = git_repo!()
    epoch = leased_epoch!()
    bogus = String.duplicate("f", 40)

    assert {:refuse, :ref_update_failed, detail} =
             DurableClose.publish(epoch.lease_token, worktree, bogus, c2)

    assert detail["unreferenced_commit"] == bogus
    assert head(worktree) == c2
  end

  # ----------------------------------------------------------------
  # Real collaborators (Chicago): real Postgres Epoch row via Ash,
  # real temp git repo on disk, real System.cmd git invocation.
  # ----------------------------------------------------------------

  defp leased_epoch!(opts \\ []) do
    expires_in = Keyword.get(opts, :expires_in, 30 * 60)
    tenant = "durable-close-court-#{System.unique_integer()}"

    run =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "durable close court", max_cycles: 1},
        authorize?: false,
        tenant: tenant
      )
      |> Ash.create!()

    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{run_id: run.id, cycle: 0, exact_subject: "durable-close-court"},
      authorize?: false,
      tenant: tenant
    )
    |> Ash.create!()
    |> Ash.Changeset.for_update(:start, %{}, authorize?: false, tenant: tenant)
    |> Ash.update!()
    |> Ash.Changeset.for_update(
      :lease,
      %{
        lease_token: "tok-court-#{System.unique_integer()}",
        lease_expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
      },
      authorize?: false,
      tenant: tenant
    )
    |> Ash.update!()
  end

  defp git_repo! do
    dir = Path.join(System.tmp_dir!(), "durable-close-court-#{System.unique_integer()}")
    File.mkdir_p!(dir)
    git!(dir, ["init"])
    git!(dir, ["config", "user.email", "court@xaas.test"])
    git!(dir, ["config", "user.name", "court"])
    File.write!(Path.join(dir, "f.txt"), "one\n")
    git!(dir, ["add", "."])
    git!(dir, ["commit", "-m", "one"])
    File.write!(Path.join(dir, "f.txt"), "two\n")
    git!(dir, ["add", "."])
    git!(dir, ["commit", "-m", "two"])
    {dir, git!(dir, ["rev-parse", "HEAD~1"]), git!(dir, ["rev-parse", "HEAD"])}
  end

  defp git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end

  defp head(worktree), do: git!(worktree, ["rev-parse", "HEAD"])
end
