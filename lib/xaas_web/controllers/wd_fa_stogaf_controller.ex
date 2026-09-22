defmodule XaasWeb.WdFaStogafController do
  use XaasWeb, :controller

  alias Xaas.CaseStudies.WdFa.{CapabilitySelector, Evaluation, Ingestion, MorningBrief, SemanticWork}
  alias Xaas.CaseStudies.WdFa.Stogaf
  alias Xaas.CaseStudies.WdFa.Stogaf.{Capabilities, Conformance, Metrics, Requirements, Viewpoints, WorkGraph}

  def show(conn, _params) do
    json(conn, %{
      architecture: Stogaf.demo_projection(),
      morning_brief: MorningBrief.summary(),
      ingestion_fixture: Ingestion.ingest_known_fixture(),
      offline_evaluation: Evaluation.offline_report(),
      demo_work: %{
        known_firmware: SemanticWork.for_case("known_firmware"),
        partial_firmware: SemanticWork.for_case("partial_firmware"),
        novel_x: SemanticWork.for_case("novel_x")
      },
      demo_capabilities: %{
        known_firmware: CapabilitySelector.for_case("known_firmware"),
        partial_firmware: CapabilitySelector.for_case("partial_firmware"),
        novel_x: CapabilitySelector.for_case("novel_x")
      },
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
