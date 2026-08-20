# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
# in lib/kanban/aws_repo/fixture_adapter.ex

defmodule Kanban.AwsRepo.FixtureAdapter do
  @behaviour Kanban.AwsRepo

  alias Kanban.AwsRepo

  @impl AwsRepo
  def get_cpu_average(_instance_id) do
    {:ok, Enum.random(1..99) + 0.123456}
  end

  @impl AwsRepo
  def get_self_instance_id do
    {:ok, "i-09ba9852c02d92e38"}
  end
end
