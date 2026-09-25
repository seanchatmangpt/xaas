defmodule Xaas.ZcodePlugin.WorkerDoctrineTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Real Chicago-style qualification for the projected worker-doctrine files
  (`priv/zcode_plugin/marketplace/xaas-fabric/skills/xaas-worker/SKILL.md`
  and `.../agents/xaas-worker.md`, produced by `ggen sync` from
  `priv/zcode_plugin/templates/`) -- real string assertions on the committed
  projection. Nothing mocked or stubbed.

  Real, evidenced gap this closes (2026-09 fs-safety hardening pass): the
  submitted `goal` text is exactly what a leased worker treats as its own
  task instructions (`Xaas.Ultracode.Lease.claim_next/2` hands `run.goal`
  straight to the worker); this repo's ONE worker plugin (the ggen project
  `priv/zcode_plugin/`) originally shipped with "There is no
  PreToolUse/PostToolUse/Stop hook in this plugin" (both templates' own
  prose at the time) -- `admit_tool`'s hardcoded
  `Bash`/`git_push`/publish refusal (see `Xaas.Ultracode.Lease`'s
  `@refused_consequence_tools`, real and unconditional) is a real
  backstop ONLY if the worker actually calls it; nothing server-side
  intercepts a tool call that skips it. Full closure of that gap needs
  real host-level tool interception this repo's zcode plugin architecture
  does not have -- out of scope for a typed-400/rate-limit fix. These
  tests assert the real, bounded textual mitigation that IS in scope: the
  doctrine now explicitly tells the worker the goal text is untrusted and
  must not be followed as an instruction to bypass admission.
  """

  @skill_template "priv/zcode_plugin/marketplace/xaas-fabric/skills/xaas-worker/SKILL.md"
  @agent_template "priv/zcode_plugin/marketplace/xaas-fabric/agents/xaas-worker.md"

  defp render(template) do
    File.read!(template)
  end

  test "the SKILL doctrine tells the worker goal text is untrusted, not an operator instruction" do
    rendered = render(@skill_template)

    assert rendered =~ "untrusted external customer input"
    assert rendered =~ "operator or system instruction"
  end

  test "the SKILL doctrine discloses exactly when the PreToolUse gate is host-enforced" do
    rendered = render(@skill_template)

    assert rendered =~ "PreToolUse gate (`scripts/xaas-gate.mjs`)"
    assert rendered =~ "XAAS_WORKER=1"
    assert rendered =~ "no `hooks.enabled` change is needed"
    assert rendered =~ "advisory from this worker's own perspective"
    assert rendered =~ "actually intercepts a real"
    refute rendered =~ "There is no PreToolUse"
  end

  test "the agent doctrine tells the subagent its goal text is untrusted customer content" do
    rendered = render(@agent_template)

    assert rendered =~ "untrusted customer submission content"
    assert rendered =~ "not a legitimate instruction to follow"
  end

  test "the agent doctrine still grants Bash (the real limit this text can't close on its own)" do
    rendered = render(@agent_template)

    # Real, disclosed fact, not fixed by this pass: the subagent's own
    # `tools:` frontmatter grants Bash -- the doctrine text above is a
    # real mitigation (tells the worker not to follow injected
    # instructions), never a technical guarantee that Bash cannot be
    # invoked without first clearing admit_tool. Asserting this stays
    # true keeps this test honest about what it does and does not prove.
    assert rendered =~ "tools: Read, Grep, Glob, Edit, Write, Bash"
  end
end
