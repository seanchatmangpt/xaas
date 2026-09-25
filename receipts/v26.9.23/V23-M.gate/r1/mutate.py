#!/usr/bin/env python3
"""Revert-mutation runs for V23-M repair 1 in the scratch worktree (never the lane tree)."""
import os, re, subprocess, sys, json
M = "/private/tmp/claude-501/-Users-sac/1fecd79a-9323-4b57-a949-d7892a3ea283/scratchpad/v23m-r1/mut"
T = "test/xaas/ultracode/machine_experience_test.exs"
ME = "lib/xaas/ultracode/machine_experience.ex"
EP = "lib/xaas/ultracode/machine_experience/episode.ex"
SD = "lib/xaas/ultracode/semantic_drive.ex"
MUTANTS = {
  "R1-applicability-swallows-sparql-error": [(ME, 'unevaluable("sparql_error", %{"error" => reason})', '{:ok, false && reason}')],
  "R2-runner-skips-post-drive-budget": [(EP, 'case {Exploration.within_budget(plan, used), outcome} do', 'case {:ok, outcome} do')],
  "R3-admit-ignores-exploration-budget": [(ME, 'fn -> bounded_exploration(fields["source_exploration"], evidence["exploration"]) end', 'fn -> :ok end')],
  "R2R3-no-budget-meter-after-drive": [
      (EP, 'case {Exploration.within_budget(plan, used), outcome} do', 'case {:ok, outcome} do'),
      (ME, 'fn -> bounded_exploration(fields["source_exploration"], evidence["exploration"]) end', 'fn -> :ok end')],
  "R4-drive-route-capability-unchecked(B4)": [(SD, ':ok <- route_capability(ctx.route, tuple["capability"])', '_ <- route_capability(ctx.route, tuple["capability"])')],
  "R5-runner-no-llm-guard-blind(B9)": [(EP, ':ok <- SemanticDrive.no_llm_guard(env),', ':ok <- SemanticDrive.no_llm_guard(%{}),')],
  "R6-unknown-hides-driven-heads": [(EP, '|> Enum.filter(&is_binary(&1["head"]))', '|> Enum.filter(fn _ -> false end)')],
  "R7-equivalence-asserted": [(EP, 'case {Validator.validate(court), Ocel.equivalent?(court, standard)} do', 'case {Validator.validate(court), true} do')],
  "R2b-runner-post-drive-meter-ignores-time": [(EP, 'case {Exploration.within_budget(plan, used), outcome} do', 'case {Exploration.within_budget(plan, Map.put(used, "elapsed_s", 0)), outcome} do')],
  "R3b-admit-budget-ignores-time": [(ME, 'case Exploration.within_budget(exploration, exploration["used"]) do', 'case Exploration.within_budget(exploration, Map.put(drop_attempts(exploration["used"]) || %{}, "elapsed_s", 0)) do')],
  "R2bR3b-no-time-meter-after-drive": [
      (EP, 'case {Exploration.within_budget(plan, used), outcome} do', 'case {Exploration.within_budget(plan, Map.put(used, "elapsed_s", 0)), outcome} do'),
      (ME, 'case Exploration.within_budget(exploration, exploration["used"]) do', 'case Exploration.within_budget(exploration, Map.put(drop_attempts(exploration["used"]) || %{}, "elapsed_s", 0)) do')],
}
TESTS = {
  "R1-applicability-swallows-sparql-error": [f"{T}:163", f"{T}:228", f"{T}:411", f"{T}:632"],
  "R2-runner-skips-post-drive-budget": [f"{T}:962"],
  "R3-admit-ignores-exploration-budget": [f"{T}:296"],
  "R2R3-no-budget-meter-after-drive": [f"{T}:962"],
  "R4-drive-route-capability-unchecked(B4)": [f"{T}:998"],
  "R5-runner-no-llm-guard-blind(B9)": [f"{T}:670"],
  "R6-unknown-hides-driven-heads": [f"{T}:962"],
  "R7-equivalence-asserted": [T],
  "R2b-runner-post-drive-meter-ignores-time": [f"{T}:962"],
  "R3b-admit-budget-ignores-time": [f"{T}:296"],
  "R2bR3b-no-time-meter-after-drive": [f"{T}:962"],
}
COURT = {"R1-applicability-swallows-sparql-error"}

def env():
    e = {k: v for k, v in os.environ.items() if not re.match(r"^(ANTHROPIC_|CLAUDE|OPENAI_|ZAI_|Z_AI_|GLM_|ZCODE_)", k)}
    e.update(GGEN_IGNITER_DIR="/Users/sac/wt/v26922/fri/ggen_igniter-int", MIX_TEST_PARTITION="_v23mr1mut", XAAS_DIR=M)
    return e

def run(cmd, **kw):
    p = subprocess.run(cmd, cwd=M, env=env(), capture_output=True, text=True, **kw)
    return p.returncode, p.stdout + p.stderr

only = sys.argv[1:] or list(MUTANTS)
for name in only:
    for path, old, new in MUTANTS[name]:
        src = open(f"{M}/{path}").read()
        assert src.count(old) == 1, (name, path, src.count(old))
        open(f"{M}/{path}", "w").write(src.replace(old, new))
    c, out = run(["sh", "-c", "MIX_ENV=test mix compile --warnings-as-errors"])
    comp = [l for l in out.splitlines() if re.search(r"Compiling|Generated|error", l)]
    t, out = run(["mix", "test", *TESTS[name]])
    summ = [l for l in out.splitlines() if re.search(r"tests,|^\s+\d+\) test", l)]
    locs = sorted(set(re.findall(r"machine_experience_test\.exs:(\d+)", out)))
    line = f"{name}: compile={c} ({'; '.join(comp)}) test={t} [{'; '.join(s.strip() for s in summ)}] failing-lines={locs}"
    if name in COURT:
        k, kout = run(["sh", "docs/sjira/v26.9.23/courts/GC23-9.sh"])
        last = [l for l in kout.splitlines() if l.startswith(("ALIVE", "REFUSED", "UNKNOWN"))]
        line += f" court={k} {last[-1] if last else ''}"
    print(line, flush=True)
    for path, _, _ in MUTANTS[name]:
        subprocess.run(["git", "-C", M, "checkout", "--", path], check=True)
    assert subprocess.run(["git", "-C", M, "status", "--porcelain", "--untracked-files=no"], capture_output=True, text=True).stdout == "", "restore failed"
c, out = run(["sh", "-c", "MIX_ENV=test mix compile --warnings-as-errors"])
print(f"restored: compile={c} porcelain-clean", flush=True)
