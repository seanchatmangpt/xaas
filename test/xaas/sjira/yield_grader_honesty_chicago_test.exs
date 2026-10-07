defmodule Xaas.Sjira.YieldGraderHonestyChicagoTest do
  @moduledoc """
  Lane W703 (autofde-lab -> xaas gap wave). Chicago-style court for the
  grader-classification honesty risk autofde-lab's AIRo risk description
  (`/Users/sac/autofde-lab/ontology/airo_risk_description.ttl`) names as
  `afl:Source_GraderClassificationGap` and `afl:Risk_SilentUndercount`:

    * a success flag must never say success when the underlying outcome state
      says otherwise (silent win), and
    * an environment-blocked outcome (`BLOCKED:ENVIRONMENT`) must never be
      counted as a model *win* -- and, per the autofde discipline, its
      presence in the denominator must be disclosed rather than silent.

  The real collaborator is `Xaas.Sjira.Yield.mine/2` over real OCEL fixture
  files written to a tmp dir and re-read through `mine_file!/2` -- no mocks.
  The classification contract is pinned on the documented success rule:
  `completed=True and standing token not in (BLOCKED|BUILD_BROKEN|REFUSED|
  REFUTED|UNSUPPORTED|UNKNOWN) and verdict not in (fail|failed|refused|
  reject|rejected)`.

  Residual gap (recorded in docs/sjira/v26.10.6/plans/w703-autofde-gaps.md,
  NOT silently asserted away here): `Xaas.Sjira.Yield` folds
  `BLOCKED:ENVIRONMENT` into the same denominator as genuine model failures
  (as a non-success), instead of separating it into its own class the way
  autofde-lab's STATUS.md pass 20 does. The disclosure control below pins
  that the fold is at least *disclosed* through `success_rule`.
  """
  use ExUnit.Case, async: true

  alias Xaas.Sjira.Yield

  setup do
    dir = Path.join(System.tmp_dir!(), "xaas-w703-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  defp ocel(dir, name, events) do
    path = Path.join(dir, name)

    File.write!(
      path,
      Jason.encode!(%{
        "objects" => [
          %{"id" => "repo:r", "type" => "repo"},
          %{"id" => "phase:Construct", "type" => "phase"},
          %{"id" => "wo:W1", "type" => "work_order"}
        ],
        "events" => events
      })
    )

    path
  end

  defp event(id, attrs),
    do: %{
      "id" => "ev:#{id}",
      "type" => "agent_completed",
      "relationships" => [
        %{"relationshipId" => "repo", "objectId" => "repo:r"},
        %{"relationshipId" => "phase", "objectId" => "phase:Construct"},
        %{"relationshipId" => "work_order", "objectId" => "wo:W1"}
      ],
      "attributes" => Enum.map(attrs, fn {k, v} -> %{"name" => to_string(k), "value" => v} end)
    }

  defp global(mined), do: mined["global"]

  test "a success flag never says success when the underlying state says otherwise", %{dir: dir} do
    # completed missing entirely -> no result -> non-success (UNKNOWN is not ADMITTED)
    mined =
      ocel(dir, "missing.json", [
        event("1", standing: "ALIVE. witnessed on the exact subject.")
      ])
      |> Yield.mine_file!()

    assert global(mined) == %{"n" => 1, "successes" => 0, "yield" => 1 / 3}

    # completed="False" -> non-success even with a perfect standing + verdict
    mined =
      ocel(dir, "false.json", [
        event("1", completed: "False", standing: "ALIVE. witnessed", verdict: "pass")
      ])
      |> Yield.mine_file!()

    assert %{"successes" => 0} = global(mined)
  end

  test "BLOCKED:ENVIRONMENT is never a silent win", %{dir: dir} do
    mined =
      ocel(dir, "blocked.json", [
        event("1",
          completed: "True",
          standing: "BLOCKED:ENVIRONMENT. 0-file Helm chart_path before the driver ran."
        )
      ])
      |> Yield.mine_file!()

    assert %{"n" => 1, "successes" => 0} = global(mined)
  end

  test "verdict classification: grader-negative verdicts deny success, grader-positive ones do not fabricate it", %{dir: dir} do
    fail =
      ocel(dir, "fail.json", [
        event("1", completed: "True", standing: "ALIVE. witnessed", verdict: "fail")
      ])
      |> Yield.mine_file!()

    assert %{"successes" => 0} = global(fail)

    refused =
      ocel(dir, "refused.json", [
        event("1", completed: "True", standing: "ALIVE. witnessed", verdict: "Refused")
      ])
      |> Yield.mine_file!()

    assert %{"successes" => 0} = global(refused)

    pass =
      ocel(dir, "pass.json", [
        event("1", completed: "True", standing: "ALIVE. witnessed", verdict: "PASS")
      ])
      |> Yield.mine_file!()

    assert %{"successes" => 1} = global(pass)
  end

  test "the denominator fold of BLOCKED is disclosed, not silent (autofde Control_YieldAccounting analog)", %{dir: dir} do
    mined =
      ocel(dir, "disclosed.json", [
        event("1", completed: "True", standing: "ALIVE. witnessed", verdict: "pass"),
        event("2",
          completed: "True",
          standing: "BLOCKED:ENVIRONMENT. 0-file chart_path."
        )
      ])
      |> Yield.mine_file!()

    # The success rule printed into the mined output names BLOCKED as a failure
    # standing: a consumer can see that BLOCKED outcomes are counted in the
    # denominator as non-successes rather than being silently hidden.
    assert mined["success_rule"] =~ "BLOCKED"

    # ...and the blocked outcome is visibly IN the denominator (n=2), not
    # dropped from it.
    assert %{"n" => 2, "successes" => 1} = global(mined)
  end

  test "classification rule string matches the module's actual failure vocabulary", %{dir: dir} do
    mined =
      ocel(dir, "rule.json", [event("1", completed: "True", standing: "ALIVE. x")])
      |> Yield.mine_file!()

    for standing <- ~w(BLOCKED BUILD_BROKEN REFUSED REFUTED UNSUPPORTED UNKNOWN) do
      assert mined["success_rule"] =~ standing
    end
  end
end
