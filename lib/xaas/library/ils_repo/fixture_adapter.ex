defmodule Xaas.Library.ILSRepo.FixtureAdapter do
  @moduledoc """
  Default `Xaas.Library.ILSRepo` adapter: real, deterministic, seeded
  in-memory fixture data reproducing the pitch deck's own live-demo script
  (slide 18) -- student Maya R., grade 6, and the three books she's shown
  reading. Real data structures a caller can assert on, not a mock of an
  interaction.

  This is the configured default (`config :xaas, Xaas.Library.ILSRepo,
  adapter: Xaas.Library.ILSRepo.FixtureAdapter`) since no real ILS vendor
  account or API credentials exist in this environment.
  """

  @behaviour Xaas.Library.ILSRepo

  alias Xaas.Library.ILSRepo

  @catalog [
    %{
      item_id: "BK-1001",
      title: "The Salt Road Cipher",
      author: "R. Okonkwo",
      grade_level: 6,
      available: true
    },
    %{
      item_id: "BK-1002",
      title: "Bloom of the Deep",
      author: "S. Ferris",
      grade_level: 6,
      available: true
    },
    %{
      item_id: "BK-1003",
      title: "Fieldwork for Beginners",
      author: "T. Nakamura",
      grade_level: 5,
      available: false
    }
  ]

  @patrons %{
    "MAYA-R-001" => %{
      patron_id: "MAYA-R-001",
      name: "Maya R.",
      grade_level: 6,
      status: "active",
      fines: 0.0,
      checked_out_count: 2
    }
  }

  @circulation_history %{
    "MAYA-R-001" => [
      %{item_id: "BK-1001", title: "The Salt Road Cipher", checked_out_at: ~D[2026-08-20]},
      %{item_id: "BK-1002", title: "Bloom of the Deep", checked_out_at: ~D[2026-08-27]}
    ]
  }

  @impl ILSRepo
  def get_catalog(_school_id), do: {:ok, @catalog}

  @impl ILSRepo
  def get_circulation_history(student_id) do
    {:ok, Map.get(@circulation_history, student_id, [])}
  end

  @impl ILSRepo
  def patron_status(patron_id) do
    case Map.fetch(@patrons, patron_id) do
      {:ok, patron} -> {:ok, patron}
      :error -> {:error, :patron_not_found}
    end
  end

  @impl ILSRepo
  def item_information(item_id) do
    case Enum.find(@catalog, &(&1.item_id == item_id)) do
      nil -> {:error, :item_not_found}
      item -> {:ok, item}
    end
  end
end
