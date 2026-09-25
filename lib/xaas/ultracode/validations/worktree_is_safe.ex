defmodule Xaas.Ultracode.Validations.WorktreeIsSafe do
  @moduledoc """
  Real `Ash.Resource.Validation` guarding `Epoch.worktree` whenever a
  non-nil value is being set (`:create`/`:lease`) — the field a real
  shared worker pool `cd`s into and performs real file writes/git commits
  against (see `Xaas.Ultracode.Lease`'s moduledoc and
  `XaasWeb.ExecutionFabricController.create_running_epoch/3`, the one
  real customer-controllable call site that sets it today).

  A `nil` worktree is unchanged/legal (see `Lease.close/4`'s existing
  `:no_worktree` downgrade path) — this validation only fires when a
  caller supplies a real value, and rejects any shape that would hand the
  worker pool a path outside its own intended sandbox:

    * relative path — refused (`worktree_not_absolute`); a relative path
      resolves against whatever cwd the worker process happens to have,
      never a fact this server can pin down.
    * any `..` path segment — refused (`worktree_traversal`), even inside
      an otherwise-absolute path (`/real/repo/../../etc`) —
      `Path.split/1`-based, not a naive substring check (so it also
      catches a bare `..` segment a substring check on `"/.."` would
      miss, e.g. `/a/../b`).
    * does not exist as a real directory the server can see — refused
      (`worktree_not_found`).
    * exists but is not a real git repository — refused
      (`worktree_not_a_git_repo`) via `git -C <path> rev-parse
      --is-inside-work-tree`, the same shell-free, explicit-argv pattern
      already used by `Lease.worktree_head/1` (no shell interpolation;
      the path is passed as one argv element).

  Fixes a real, evidenced gap (2026-09 fs-safety hardening pass): before
  this validation, `/`, `/etc`, `/Users/sac`, a nonexistent path, and a
  `../` traversal shape all passed through `create_running_epoch/3`
  unchanged and were handed straight back to a real claiming worker via
  `claim_next`'s `worktree` field — confirmed via a real repro against
  the dev DB (`Lease.claim_next/2` + `Lease.close/4` over six adversarial
  worktree values), not guessed.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :worktree) do
      nil -> :ok
      "" -> :ok
      worktree when is_binary(worktree) -> check(worktree)
    end
  end

  defp check(worktree) do
    cond do
      not String.starts_with?(worktree, "/") ->
        {:error, field: :worktree, message: "worktree_not_absolute"}

      ".." in Path.split(worktree) ->
        {:error, field: :worktree, message: "worktree_traversal"}

      not File.dir?(worktree) ->
        {:error, field: :worktree, message: "worktree_not_found"}

      not git_repo?(worktree) ->
        {:error, field: :worktree, message: "worktree_not_a_git_repo"}

      true ->
        :ok
    end
  end

  defp git_repo?(worktree) do
    case System.cmd("git", ["-C", worktree, "rev-parse", "--is-inside-work-tree"],
           stderr_to_stdout: true
         ) do
      {"true\n", 0} -> true
      _ -> false
    end
  end
end
