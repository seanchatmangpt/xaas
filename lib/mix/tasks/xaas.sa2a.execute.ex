defmodule Mix.Tasks.Xaas.Sa2a.Execute do
  @moduledoc """
  Autonomic SA2A `sa2a_execute` for workers: no prompt, no human.

  Reads a JSON request (see `Xaas.Sa2a.Executor` for its shape), starts the real
  `autofde beam-bridge` port, and routes the call through `Xaas.Sa2a.Executor` ->
  `Xaas.Actuation.run/4`. Prints a single JSON envelope on stdout.

  Exit code: `0` for `succeeded` / `replayed`; non-zero (`Mix.raise`) for `refused`,
  `blocked`, `forbidden` or any other error, so a worker/dispatcher can branch on it.

      export PATH=$HOME/autofde-lab/.venv/bin:$PATH
      mix xaas.sa2a.execute request.json
      cat request.json | mix xaas.sa2a.execute -
  """
  use Mix.Task

  @shortdoc "Autonomic SA2A execute (Reactor/BRCE path, machine policy, replay-verified)"

  @impl Mix.Task
  def run([source]) do
    Mix.Task.run("app.start")

    request =
      source
      |> read()
      |> Jason.decode!()

    case Xaas.Sa2a.Executor.execute(request, start_bridge?: true) do
      {:ok, envelope} ->
        emit(%{
          "status" => Atom.to_string(envelope.status),
          "idempotency_key" => envelope.idempotency_key,
          "result" => envelope.execution.result,
          "llm_avoidance_ratio" => envelope.execution.llm_avoidance_ratio,
          "manifest_hash" => envelope.execution.manifest_hash,
          "execution_id" => envelope.execution.id,
          "intent_id" => envelope.intent.id,
          "receipt_id" => envelope.receipt.id
        })

      {:error, {:refused, code, detail}} ->
        fail("refused", %{"code" => Atom.to_string(code), "detail" => detail})

      {:error, {:blocked, why}} ->
        fail("blocked", %{"why" => inspect(why)})

      {:error, %Ash.Error.Forbidden{} = error} ->
        fail("forbidden", %{"error" => Exception.message(error)})

      {:error, other} ->
        fail("error", %{"error" => inspect(other)})
    end
  end

  def run(_args), do: Mix.raise("usage: mix xaas.sa2a.execute <request.json | ->")

  defp read("-"), do: IO.read(:stdio, :eof)
  defp read(path), do: File.read!(path)

  defp emit(map), do: IO.puts(Jason.encode!(map))

  defp fail(status, body) do
    emit(Map.put(body, "status", status))
    Mix.raise("sa2a execute #{status}")
  end
end
