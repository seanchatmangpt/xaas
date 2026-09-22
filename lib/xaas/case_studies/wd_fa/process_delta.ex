defmodule Xaas.CaseStudies.WdFa.ProcessDelta do
  @moduledoc """
  Evidence-bounded process delta for the verified novel fixture.

  It reports a change in semantic work class, not a production time saving.
  """

  alias Xaas.CaseStudies.WdFa
  alias Xaas.CaseStudies.WdFa.SemanticWork

  @spec verified_replay_delta() :: map()
  def verified_replay_delta do
    before_state = WdFa.presentation_state("novel_x")
    after_state = WdFa.presentation_state("novel_x", true)
    before_work = SemanticWork.for_case("novel_x")
    after_work = SemanticWork.for_case("novel_x", true)

    %{
      evidence_ceiling: "REPO_LOCAL_FIXTURE",
      before: %{
        classification: before_state.classification,
        work_standing: before_work.standing,
        obligation: before_work.obligation
      },
      after: %{
        classification: after_state.classification,
        work_standing: after_work.standing,
        obligation: after_work.obligation
      },
      novel_investigation_retired:
        before_work.standing == "NOVEL_INVESTIGATION_REQUIRED" and
          after_work.standing == "READY_FOR_ENGINEER_DISPOSITION",
      production_time_saved: "UNMEASURED"
    }
  end
end
