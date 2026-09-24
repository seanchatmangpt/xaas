#!/usr/bin/env python3
"""Revert-mutation runs for V23-M repair 2 in a scratch worktree of the committed subject (never the lane tree).
Each mutant keeps the API and reverts one repair-2 behavior; it is killed when the lane gate's test file
or the GC23-9 court fails on it. The tree is restored (git checkout) after each mutant."""
import os, re, subprocess, sys
S = "/private/tmp/claude-501/-Users-sac/1fecd79a-9323-4b57-a949-d7892a3ea283/scratchpad/v23m-r2"
W = f"{S}/mut"
T = "test/xaas/ultracode/machine_experience_test.exs"
ME = "lib/xaas/ultracode/machine_experience.ex"
EP = "lib/xaas/ultracode/machine_experience/episode.ex"
MUTANTS = {
  "M1-route-skips-admission-digest": [(ME, 'admission["admission_digest"] == admission_digest(record, admission),', 'true,')],
  "M2-skips-experience-digest": [(ME, 'check(computed == record["experience_digest"], "experience_digest_mismatch", %{', 'check(is_binary(computed), "experience_digest_mismatch", %{')],
  "M3-invalid-admissions-ignored(REFUTE-2)": [(ME, 'with :ok <- verified(judged, row),', 'with _ <- verified(judged, row),')],
  "M4-closure-skipped": [(ME, 'check(MapSet.size(extra) == 0 and MapSet.size(missing) == 0, "admission_not_closed", %{', 'check(MapSet.size(extra) >= 0, "admission_not_closed", %{')],
  "M5-admission-digest-binds-only-experience-digest(v1)": [(ME, '"experience" => experience,', '"experience" => Map.take(experience, ["experience_digest"]),')],
  "M6-refs-order-unchecked": [(ME, 'refs == refs |> Enum.uniq() |> Enum.sort(),', 'is_list(refs),')],
  "M7-runner-unsorted-refs": [(EP, '      |> Enum.map(&Path.join(evidence["dir"], &1))\n      |> Enum.sort()\n', '      |> Enum.map(&Path.join(evidence["dir"], &1))\n')],
  "M8-ggen-digest-formula-drift": [(ME, '|> Map.drop(@ggen_elided)', '|> Map.drop(["experience_digest"] ++ Enum.take(@ggen_elided, 0))')],
}
env = {k: v for k, v in os.environ.items() if not re.match(r'^(ANTHROPIC_|CLAUDE|OPENAI_|ZAI_|Z_AI_|GLM_|ZCODE_)', k)}
env.update(GGEN_IGNITER_DIR="/Users/sac/wt/v26922/fri/ggen_igniter-int", MIX_TEST_PARTITION="_v23mr2mut", XAAS_DIR=W)
noise = re.compile(r'Application.get_env|│|└─|^\s*$|\[warning\]|^longnames|erlang.org')
def run(cmd, extra=None):
    e = dict(env, **(extra or {}))
    p = subprocess.run(cmd, cwd=W, env=e, shell=True, capture_output=True, text=True)
    return p.returncode, "\n".join(l for l in (p.stdout + p.stderr).splitlines() if not noise.search(l))
def summary(out, pats):
    return [l.strip() for l in out.splitlines() if any(re.search(p, l) for p in pats)]
c, o = run(f"git status --porcelain | wc -l; git rev-parse HEAD")
print("scratch:", W, o.split()[-1], "porcelain", o.split()[0], flush=True)
c, o = run("MIX_ENV=test mix compile --warnings-as-errors")
print(f"BASELINE compile {c}", flush=True)
c, o = run(f"mix test {T}")
print(f"BASELINE test {c}: " + " | ".join(summary(o, [r'tests,'])), flush=True)
c, o = run("sh docs/sjira/v26.9.23/courts/GC23-9.sh")
print(f"BASELINE court {c}: " + " | ".join(summary(o, [r'^ALIVE', r'^REFUSED', r'^UNKNOWN'])), flush=True)
killed = {}
for name, edits in MUTANTS.items():
    for path, old, new in edits:
        src = open(f"{W}/{path}").read()
        assert src.count(old) == 1, (name, path, old)
        open(f"{W}/{path}", "w").write(src.replace(old, new))
    cc, co = run("MIX_ENV=test mix compile --warnings-as-errors")
    tc, to = run(f"mix test {T}")
    kc, ko = run("sh docs/sjira/v26.9.23/courts/GC23-9.sh")
    fails = summary(to, [r'tests,', r'^\s*\d+\) test'])
    court = summary(ko, [r'^ALIVE', r'^REFUSED', r'^UNKNOWN'])
    killed[name] = tc != 0 or kc != 0
    print(f"{name}: compile {cc}{' (' + ' | '.join(summary(co, [r'warning:|error'])[:2]) + ')' if cc else ''}; "
          f"test {tc}: {' | '.join(fails)}; court {kc}: {' | '.join(court)[:400]}; "
          f"{'KILLED' if killed[name] else 'SURVIVED'}", flush=True)
    run("git checkout -- lib")
c, o = run("MIX_ENV=test mix compile --warnings-as-errors; git status --porcelain | wc -l")
print(f"RESTORED compile {c}; porcelain {o.split()[-1]}")
survived = [k for k, v in killed.items() if not v]
print(f"KILLED {len(killed) - len(survived)}/{len(killed)}" + (f"; survived: {', '.join(survived)}" if survived else ""))
sys.exit(0 if all(killed.values()) else 1)
