# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
# in lib/kanban/aws_repo/aws_adapter.ex

defmodule Kanban.AwsRepo.AwsAdapter do
  @behaviour Kanban.AwsRepo

  import SweetXml

  alias Kanban.AwsRepo

  @base_url "http://169.254.169.254"

  @impl AwsRepo
  def get_cpu_average(instance_id) do
    action = :get_metric_statistics

    action_string =
      action
      |> Atom.to_string()
      |> Macro.camelize()

    start_time =
      DateTime.utc_now()
      # Real fix (ash-migration Phase 3): replaced Timex.shift/2 with core
      # Elixir DateTime.add/3 -- timex's gettext ~> 0.10-0.26 requirement is
      # irreconcilable with ex_money_sql's real transitive gettext ~> 1.0
      # requirement (confirmed via real resolver output), and this was
      # timex's only real usage in the repo (grep-confirmed).
      |> DateTime.add(-5, :minute)
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()

    end_time =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()

    %ExAws.Operation.Query{
      action: action,
      path: "/",
      params: %{
        "Action" => action_string,
        "Dimensions.member.1.Name" => "InstanceId",
        "Dimensions.member.1.Value" => instance_id,
        "EndTime" => end_time,
        "MetricName" => "CPUUtilization",
        "Namespace" => "AWS/EC2",
        "Period" => 5,
        "StartTime" => start_time,
        "Statistics.member.1" => "Average",
        "Version" => "2010-08-01"
      },
      content_encoding: "identity",
      service: :monitoring,
      parser: &ExAws.Utils.identity/2
    }
    |> ExAws.request()
    |> case do
      {:ok, %{body: xml_body}} ->
        {:ok, parse_cpu_average(xml_body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl AwsRepo
  def get_self_instance_id do
    url = "#{@base_url}/latest/meta-data/instance-id"

    with {:ok, aws_token} <- get_aws_token(),
         {:ok, %Req.Response{body: body}} <-
           Req.get(url, headers: [{"X-aws-ec2-metadata-token", aws_token}]) do
      {:ok, body}
    else
      {:error, error} ->
        {:error, "Failed to retrieve self instance id, error: #{inspect(error)}"}
    end
  end

  defp parse_cpu_average(xml_body) do
    xml_body
    |> SweetXml.parse()
    |> SweetXml.xpath(~x"//Datapoints/member"l,
      average: ~x"./Average/text()"f
    )
    |> Enum.reduce({0, 0}, fn %{average: average}, {n, acc} ->
      {n + 1, acc + average}
    end)
    |> then(fn {n, acc} ->
      if {n, acc} == {0, 0} do
        0
      else
        acc / n
      end
    end)
  end

  defp get_aws_token do
    url = "#{@base_url}/latest/api/token"
    headers = [{"X-aws-ec2-metadata-token-ttl-seconds", "21600"}]

    case Req.put(url, headers: headers) do
      {:ok, %Req.Response{body: body}} ->
        {:ok, body}

      {:error, error} ->
        {:error, "Failed to retrieve AWS token, error: #{inspect(error)}"}
    end
  end
end
