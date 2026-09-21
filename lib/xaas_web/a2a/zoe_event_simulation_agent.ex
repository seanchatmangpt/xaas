defmodule XaasWeb.A2A.ZoeEventSimulationAgent do
  @moduledoc """
  Internal-token-gated A2A surface for the deterministic ZOE event simulator.

  This agent exposes a simulation skill only. It does not dispatch production
  consequences and never grants SA2A DO authority.
  """

  use A2A.Agent,
    name: "zoe-event-simulation",
    description:
      "Runs a full ZOE event operations simulation with SA2A-shaped authority-free capability traces",
    skills: [
      %{
        id: "simulate-event",
        name: "Simulate ZOE event",
        description:
          "Simulate administration, registration, attendance, security, incidents, reinforcement, and reconciliation",
        tags: ["zoe", "event-ops", "sa2a", "simulation"]
      },
      %{
        id: "contract",
        name: "Inspect simulation contract",
        description: "Return the authority and evidence ceiling for the ZOE event simulator",
        tags: ["zoe", "event-ops", "contract"]
      }
    ]

  @impl A2A.Agent
  def handle_message(message, _context) do
    text = A2A.Message.text(message) || ""

    cond do
      text == "contract" ->
        {:reply, [A2A.Part.Text.new(Jason.encode!(Xaas.Zoe.EventSimulation.contract()))]}

      String.starts_with?(text, "simulate ") ->
        run_simulation(String.replace_prefix(text, "simulate ", ""))

      true ->
        {:input_required,
         [
           A2A.Part.Text.new(
             "Expected: contract | simulate {\"snapshot\": {...}, \"scenario\": {...}}"
           )
         ]}
    end
  end

  defp run_simulation(raw_json) do
    with {:ok, payload} <- Jason.decode(raw_json),
         snapshot when is_map(snapshot) <- Map.get(payload, "snapshot"),
         scenario when is_map(scenario) <- Map.get(payload, "scenario", %{}),
         {:ok, result} <- Xaas.Zoe.EventSimulation.simulate(snapshot, scenario) do
      {:reply, [A2A.Part.Text.new(Jason.encode!(result))]}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, "invalid simulation JSON: #{Exception.message(error)}"}

      {:error, reason} ->
        {:error, "simulation refused: #{inspect(reason)}"}

      _ ->
        {:error, "simulation refused: snapshot and scenario must be JSON objects"}
    end
  end
end
