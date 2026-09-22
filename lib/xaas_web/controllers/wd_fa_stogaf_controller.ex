defmodule XaasWeb.WdFaStogafController do
  use XaasWeb, :controller

  alias Xaas.CaseStudies.WdFa.Stogaf
  alias Xaas.CaseStudies.WdFa.Stogaf.{Capabilities, Conformance, Metrics, Requirements, Viewpoints, WorkGraph}

  def show(conn, _params) do
    json(conn, %{
      architecture: Stogaf.demo_projection(),
      conformance: Conformance.all(),
      requirements: Requirements.all(),
      viewpoints: Viewpoints.all(),
      work_graph: WorkGraph.all(),
      capabilities: Capabilities.friday(),
      excluded_production_do: Capabilities.production_do(),
      dfcm: Metrics.summary()
    })
  end
end
