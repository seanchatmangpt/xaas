defmodule Xaas.Ultracode.DurableClose do
  @moduledoc """
  Common lease-fenced Git publication primitive for Ultracode construction
  providers.

  A candidate commit is not durable work until a reachable ref moves to it
  while the epoch lease is still live. This module owns that compare-and-swap
  fence so zcode, recipe, and future providers do not reimplement publication
  authority in worker logic.
  """

  import Ecto.Query, only: [from: 2]

  alias Xaas.Ultracode.{DurationBudget, Epoch}

  @spec publish(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          :ok
          | {:lease_lost, term(), String.t()}
          | {:refuse, atom(), map()}
  def publish(token, worktree, commit, base_head, opts \\ [])
      when is_binary(token) and is_binary(worktree) and is_binary(commit) and
             is_binary(base_head) do
    message = Keyword.get(opts, :message, "ultracode: fenced durable close")

    fenced =
      Xaas.Repo.transaction(fn ->
        row =
          Xaas.Repo.one(
            from(e in Epoch,
              where: e.lease_token == ^token,
              lock: "FOR UPDATE"
            )
          )

        with :ok <- live_row(row),
             {_, 0} <-
               System.cmd(
                 "git",
                 [
                   "-C",
                   worktree,
                   "update-ref",
                   "-m",
                   message,
                   "HEAD",
                   commit,
                   base_head
                 ],
                 stderr_to_stdout: true
               ) do
          :ok
        else
          {:lost, reason} -> Xaas.Repo.rollback({:lost, reason})
          {out, code} -> Xaas.Repo.rollback({:ref_update_failed, "#{code}: #{out}"})
        end
      end)

    case fenced do
      {:ok, :ok} ->
        :ok

      {:error, {:lost, reason}} ->
        {:lease_lost, reason, commit}

      {:error, {:ref_update_failed, git_out}} ->
        {:refuse, :ref_update_failed,
         %{
           "git" => git_out,
           "unreferenced_commit" => commit
         }}

      {:error, other} ->
        {:refuse, :fence_failed,
         %{
           "fence" => inspect(other),
           "unreferenced_commit" => commit
         }}
    end
  end

  defp live_row(nil), do: {:lost, :no_lease}

  defp live_row(%Epoch{state: :running, lease_expires_at: %DateTime{} = expires_at}) do
    if DateTime.compare(expires_at, DurationBudget.now()) == :lt,
      do: {:lost, :lease_expired},
      else: :ok
  end

  defp live_row(%Epoch{state: :running}), do: {:lost, :lease_expired}
  defp live_row(%Epoch{state: state}), do: {:lost, {:lease_not_live, state}}
end
