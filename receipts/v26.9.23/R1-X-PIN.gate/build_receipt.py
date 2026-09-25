#!/usr/bin/env python3
"""Builds receipts/v26.9.23/R1-X-PIN.json from the committed evidence (scratch helper, lane R1-X-PIN)."""
import hashlib
import json
import subprocess
from pathlib import Path

WT = Path("/Users/sac/wt/v26922/v23/R1-X-PIN")
GD = "receipts/v26.9.23/R1-X-PIN.gate"
PIN = "PATH=/Users/sac/.asdf/installs/elixir/1.20.2-otp-28/bin:/Users/sac/.asdf/installs/erlang/28.5.0.2/bin:$PATH"
SUBJECT = "f932e6b76b859dd27cb95c4d5085c50ccec84507"
BASE = "c68c74dcf4e405e4382d34d51288763afc5939b0"
FIX = "60972f8e9757a4e4bd45ef265781518d5ccdebdf"
PICK = "3ea1cfc"
LEDGER = SUBJECT
GI = "/Users/sac/wt/v26922/fri/ggen_igniter-int"
CWD = str(WT)


def git(*args):
    return subprocess.run(["git", "-C", CWD, *args], capture_output=True, text=True, check=True).stdout.strip()


def sha(rel):
    return hashlib.sha256((WT / rel).read_bytes()).hexdigest()


PICK = git("rev-parse", PICK)
files_changed = git("diff", "--name-only", BASE, SUBJECT).splitlines()

gate_a = (
    f"{PIN} sh -c 'elixir --version && mix format --check-formatted && MIX_ENV=test mix compile --force "
    f"--warnings-as-errors && GGEN_IGNITER_DIR={GI} mix test'"
)
gate_b = f"{PIN} sh -c 'MIX_ENV=dev mix deps.compile --force postgrex && MIX_ENV=dev mix dialyzer --format github'"
gate_c = (
    f"T=$(mktemp -d) && {PIN} env HOME=$T MIX_HOME=/Users/sac/.mix HEX_HOME=/Users/sac/.hex MIX_ENV=test "
    "mix test test/xaas/receipt/r_projection_test.exs > $T/rp.log 2>&1; tail -5 $T/rp.log; "
    "grep -Eq '8 tests, 0 failures, 5 skipped|Result: 3 passed, 5 skipped' $T/rp.log"
)
suite2 = f"{PIN} GGEN_IGNITER_DIR={GI} mix test"
fals = "sh receipts/v26.9.23/R1-X-PIN.gate/falsifiers/falsify.sh /Users/sac/wt/v26922/v23/R1-X-PIN /private/tmp/claude-501/v23-scratch/R1c-R1-X-PIN/fals"

commands = [
    {
        "cmd": gate_a, "cwd": CWD, "exit": 0, "round": "final", "subject": SUBJECT, "role": "lane gate part A (full suite run 1)",
        "summary": "Elixir 1.20.2 (OTP 28, erts 16.4.0.2); format 0; compile --force --warnings-as-errors 0; full suite seed 879900: "
                   "Result: 1895 passed, 76 excluded (0 failures) in 455.3 s; tree clean before and after",
        "log": f"{GD}/subject-f932e6b/gateA-suite-run1.log", "output_sha256": sha(f"{GD}/subject-f932e6b/gateA-suite-run1.log"),
    },
    {
        "cmd": gate_b, "cwd": CWD, "exit": 0, "round": "final", "subject": SUBJECT, "role": "lane gate part B (dialyzer, ci_cd.yaml job ci step)",
        "summary": "postgrex recompiled in-tree (ignore entry matches); 'Total errors: 29, Skipped: 29, Unnecessary Skips: 0', "
                   "'done (passed successfully)'; no .dialyzer_ignore.exs change",
        "log": f"{GD}/subject-f932e6b/gateB-dialyzer.log", "output_sha256": sha(f"{GD}/subject-f932e6b/gateB-dialyzer.log"),
    },
    {
        "cmd": gate_c, "cwd": CWD, "exit": 0, "round": "final", "subject": SUBJECT, "role": "lane gate part C (empty-HOME r_projection clause)",
        "summary": "HOME = a fresh mktemp dir (no ~/.claude/dfcm/validate_receipt.py): 'Result: 3 passed, 5 skipped' -- the 5 "
                   "validator-calling tests skip by name, the 3 fabric-only refusal tests run",
        "log": f"{GD}/subject-f932e6b/gateC.log", "output_sha256": sha(f"{GD}/subject-f932e6b/gateC-rp.log"),
    },
    {
        "cmd": suite2, "cwd": CWD, "exit": 0, "round": "final", "subject": SUBJECT, "role": "full suite run 2 (order dependence)",
        "summary": "second full run, fresh seed 684346: Result: 1895 passed, 76 excluded (0 failures) in 733.1 s; tree clean before and after",
        "log": f"{GD}/subject-f932e6b/suite-run2.log", "output_sha256": sha(f"{GD}/subject-f932e6b/suite-run2.log"),
    },
    {
        "cmd": "sh -c '! grep -n \"unittest.mock\\|Mock(\\|MagicMock\\|patch(\\|monkeypatch\\|Mox\\b\\|:meck\\|meck\\.\" <the 7 lane-touched test files + 3 lane-touched lib files>'",
        "cwd": CWD, "exit": 0, "round": "final", "subject": SUBJECT, "role": "Chicago mock grep (xaas CLAUDE.md pattern) over lane-changed files",
        "summary": "0 matches in the changed test/lib files; the whole-tree grep (subject-f932e6b/mockgrep-tree.log) has 178 pre-existing "
                   "matches: 172 HTTP `patch(` verbs and 6 comment/string literals, none in a lane-changed file",
        "log": f"{GD}/subject-f932e6b/mockgrep-changed-inverted.log", "output_sha256": sha(f"{GD}/subject-f932e6b/mockgrep-changed-inverted.log"),
    },
]
for name, summary in [
    ("nil-clauses", "restoring the two `nil -> []` clauses + `is_map(hops) &&`: dialyzer inner exit 2, 'Total errors: 32, Skipped: 29', "
                    "pattern_match at machine_experience.ex:539 and :1235, guard_fail at xaas.episode.ex:191; restored, tree clean"),
    ("rproj-guard", "removing the 5 `@tag skip: @needs_validator`: empty-HOME clause inner exit 2, 'Result: 3/8 passed' (5 failures "
                    "\"can't open file .../validate_receipt.py\"); restored, tree clean"),
    ("manifest-vsn1", "manifest reader matching only {_vsn, compiler, _scm} (the scan's vsn-1-only shape): inner exit 2, 2/7 passed; "
                      "fails 'a build compiled by this node's Elixir on this ERTS resolves to that Elixir (source build_manifest)' and "
                      "'both declared manifest shapes are read' (the 1.20.2 manifest is {2, {\"1.20.2\", ~c\"28\"}, Mix.SCM.Path, nil})"),
    ("manifest-any", "manifest reader of c68c74d (element 1 of any 3-/4-tuple): inner exit 2, 6/7 passed; fails 'an undeclared manifest "
                     "shape is REFUSED(build_manifest_shape)' (a vsn-3 4-tuple is read by position)"),
    ("gi-mix", "gi_mix.sh of c68c74d (caller's mix): GC23-0 court under the xaas pin inner exit 1 -- 'could not compile dependency "
               ":faker' then 'REFUSED: GC23-0 compile_prose --check exited 1'; restored, tree clean"),
    ("court-policy", "court_repo/1 without priv/no_llm/policy.json: the GC23-0 and GC23-3 court-copy tests inner exit 2, 0/2 passed, "
                     "'UNKNOWN: no_llm_env: no policy data at .../priv/no_llm/policy.json'"),
    ("port-hash", "undo OCEL test of c68c74d (hash-derived port) with every port 42777..43276 held by a real listener (500 held): "
                  "inner exit 2, 3x ':eaddrinuse', 0/3 passed; restored"),
    ("port-held-committed", "the committed test (port 0) under the same 500 held ports: inner exit 0, 'Result: 3 passed'"),
]:
    commands.append({
        "cmd": f"{fals} {name}", "cwd": CWD, "exit": 0, "round": "final", "subject": SUBJECT,
        "role": "revert-mutation falsifier (harness exit 0 iff the mutated check failed the expected way and the tree is restored clean)",
        "summary": summary,
        "log": f"{GD}/falsifiers/falsify-{name}.log", "output_sha256": sha(f"{GD}/falsifiers/falsify-{name}.log"),
        "inner_log": f"{GD}/falsifiers/falsify-{name}.inner.log",
    })
commands += [
    {
        "cmd": f"python3 {GD}/dispatch_fence.py $PWD {SUBJECT} refs/heads/v23/R1-X-PIN && gh workflow run ci_cd.yaml --repo seanchatmangpt/xaas --ref v23/R1-X-PIN",
        "cwd": CWD, "exit": 0, "round": "final", "subject": SUBJECT, "role": "R1-X-FENCE-gated hosted dispatch (remote effect)",
        "summary": "YAML parse of ci_cd.yaml at the pushed SHA: publish-image and deploy `if:` are pure && conjunctions containing "
                   "github.ref == 'refs/heads/main', false for refs/heads/v23/R1-X-PIN -> FENCE HOLDS; anti-vacuity: the same proof "
                   "for refs/heads/main refuses (exit 1, subject-60972f8/dispatch_fence-60972f8-main-refusal.log). Dispatched run "
                   "35943406033 (headSha f932e6b, event workflow_dispatch): publish-image and deploy skipped",
        "log": f"{GD}/subject-f932e6b/dispatch_fence-f932e6b.log", "output_sha256": sha(f"{GD}/subject-f932e6b/dispatch_fence-f932e6b.log"),
    },
    {
        "cmd": "gh run view 35943406033 --repo seanchatmangpt/xaas --json databaseId,headSha,headBranch,event,status,conclusion,createdAt,updatedAt,url,jobs",
        "cwd": CWD, "exit": 0, "round": "final", "subject": SUBJECT, "role": "hosted exact-head CI observation (CE23-5, job ci)",
        "summary": "job 'Exact-head test court' (ci_cd.yaml job ci) = success at headSha f932e6b: Elixir 1.20.2 / OTP 28 erts 16.4.0.2, "
                   "format, compile --force --warnings-as-errors, `mix test --max-failures 1 --trace` 'Result: 1796 passed, 99 skipped, "
                   "76 excluded', dialyzer 'Total errors: 29, Skipped: 29, Unnecessary Skips: 0' 'done (passed successfully)', "
                   "deps.unlock --check-unused; run conclusion cancelled only because job production ('Exact-head production compile "
                   "court', timeout-minutes 12, cancelled mid C++ NIF compile) -- owned by R2-X-PROD-TIMEOUT, not this lane",
        "log": f"{GD}/hosted/run-35943406033.json", "output_sha256": sha(f"{GD}/hosted/run-35943406033.json"),
        "job_log": f"{GD}/hosted/run-35943406033-job-107456040537-test-court.log.gz",
    },
    {
        "cmd": "python3 ~/.claude/dfcm/validate_receipt.py receipts/v26.9.23/R1-X-PIN.json",
        "cwd": CWD, "exit": 0, "round": "final", "role": "receipt admission", "summary": "ADMITTED",
    },
]

witnesses = [
    {
        "cmd": f"{PIN} GGEN_IGNITER_DIR={GI} mix test", "cwd": CWD, "exit": 2, "subject": BASE, "role": "pinned full suite at the lane base (what the pinned run reported)",
        "summary": "seed 7528, 'Result: 1888/1893 passed, 76 excluded / Failed: 5 tests' (graph checkout ggen_igniter-int 3ed6a7a): "
                   "ActuationOcelUndoTest :eaddrinuse; V26923GoalTest GC23-0 subprocess (GC23-0 not ALIVE), registry (GC23-12 "
                   "'REFUSED: GC23-12 compile_prose --check exited 1'), GC23-0 and GC23-3 court copies ('no_llm_env: no policy data')",
        "log": f"{GD}/base-c68c74d/suite-full.log", "output_sha256": sha(f"{GD}/base-c68c74d/suite-full.log"),
    },
    {
        "cmd": f"{PIN} MIX_ENV=test mix compile --force --warnings-as-errors", "cwd": CWD, "exit": 0, "subject": BASE,
        "role": "fresh _build/test under the pin at the base (deps APFS-cloned from xaas-int, mix.lock identical)",
        "summary": "8m15s fresh compile of every dependency and 521 xaas files, exit 0 (the unused require Ash.Query was already gone via c614b9a)",
        "log": f"{GD}/base-c68c74d/compile-test-warnings-as-errors.log", "output_sha256": sha(f"{GD}/base-c68c74d/compile-test-warnings-as-errors.log"),
    },
    {
        "cmd": f"{PIN} MIX_ENV=dev mix deps.compile --force postgrex", "cwd": CWD, "exit": 1, "subject": BASE,
        "role": "environment: the gate's first dialyzer command on a FRESH _build/dev",
        "summary": "postgrex cannot compile before its own deps exist in _build/dev ('cannot infer signatures from :db_connection ... "
                   "Compilation error in file lib/postgrex/parameters.ex'); after one `mix dialyzer` compiled the dev deps the same "
                   "command exits 0 (every later gate B run). Environment, not subject",
        "log": f"{GD}/base-c68c74d/dialyzer-postgrex-fresh-build-dev.log", "output_sha256": sha(f"{GD}/base-c68c74d/dialyzer-postgrex-fresh-build-dev.log"),
    },
    {
        "cmd": f"{PIN} MIX_ENV=dev mix dialyzer --format github", "cwd": CWD, "exit": 2, "subject": BASE, "role": "pinned dialyzer at the base",
        "summary": "'Total errors: 32, Skipped: 29, Unnecessary Skips: 0': guard_fail xaas.episode.ex:191, pattern_match "
                   "machine_experience.ex:539 and :1235 (the scan's e999e62 count was 31; the :191 guard_fail entered with a4c2924)",
        "log": f"{GD}/base-c68c74d/dialyzer.log", "output_sha256": sha(f"{GD}/base-c68c74d/dialyzer.log"),
    },
    {
        "cmd": f"{PIN} env XAAS_DIR=$PWD GGEN_IGNITER_DIR={GI} MIX_ENV= sh docs/sjira/v26.9.23/courts/GC23-0.sh", "cwd": CWD, "exit": 1, "subject": BASE,
        "role": "root cause of the two V26923GoalTest court failures",
        "summary": "gi_mix.sh ran ggen_igniter's compile_prose with the caller's mix (1.20.2) against ggen_igniter-int _build/test "
                   "compiled by 1.18.4/OTP 27 ({1, {\"1.18.4\", \"27\"}, Mix.SCM.Path}): full recompile, 'could not compile dependency "
                   ":faker', 'REFUSED: GC23-0 compile_prose --check exited 1'. With the lane's gi_mix.sh the same court is "
                   "'ALIVE: GC23-0' (wip-uncommitted/gc23-0-direct-wip.log)",
        "log": f"{GD}/base-c68c74d/gc23-0-court-under-pin.log", "output_sha256": sha(f"{GD}/base-c68c74d/gc23-0-court-under-pin.log"),
    },
    {
        "cmd": "gh workflow run ci_cd.yaml --repo seanchatmangpt/xaas --ref v23/R1-X-PIN  (run 35941961752)", "cwd": CWD, "exit": 1, "subject": FIX,
        "role": "hosted exact-head CI at the first lane head 60972f8",
        "summary": "job ci failed at test/xaas/ultracode/court_receipt_test.exs:306 (REAL ggen-igniter-format court: acceptance false, "
                   "the suite's asdf 1.18.4-otp-27 mix is absent on setup-beam) under --max-failures 1 -> host-coupled named skips "
                   "cherry-picked (3ea1cfc from r2 pre-flight f7dde47); production cancelled (timeout); publish/deploy skipped",
        "log": f"{GD}/hosted/run-35941961752.json", "output_sha256": sha(f"{GD}/hosted/run-35941961752.json"),
        "job_log": f"{GD}/hosted/run-35941961752-job-107451584054-test-court.log.gz",
    },
    {
        "cmd": f"{PIN} [+ gate A/B/C and suite run 2] at 60972f8", "cwd": CWD, "exit": 0, "subject": FIX,
        "role": "the same lane gate at the first lane head (superseded by the final subject)",
        "summary": "gate A seed 960554 1895 passed; gate B 29/29 passed; gate C 3 passed 5 skipped; suite run 2 seed 614709 1895 passed",
        "log": f"{GD}/subject-60972f8/gateA-suite-run1.log", "output_sha256": sha(f"{GD}/subject-60972f8/gateA-suite-run1.log"),
    },
    {
        "cmd": f"{PIN} [host] mix test successor_test court_receipt_test semantic_receipt_test; env -i HOME=<fresh> PATH=<pin>:/usr/bin:/bin GGEN_IGNITER_DIR=<absent> mix test --trace <same>",
        "cwd": CWD, "exit": 0, "subject": SUBJECT, "role": "named-skip verification (host vs CI-like environment)",
        "summary": "host: 'Result: 53 passed'; CI-like (fresh HOME, no asdf/Homebrew on PATH, no ggen_igniter checkout): 'Result: 48 "
                   "passed, 5 skipped' (the 2 REAL ggen-igniter-format courts, successor_law.py, the 2 ggen_igniter-checkout tests)",
        "log": f"{GD}/subject-f932e6b/hostskip-cilike.log", "output_sha256": sha(f"{GD}/subject-f932e6b/hostskip-cilike.log"),
    },
]
for name in ["nil-clauses", "rproj-guard", "manifest-vsn1", "manifest-any", "gi-mix", "court-policy", "port-hash"]:
    witnesses.append({
        "cmd": f"(inner check of falsifier {name})", "cwd": CWD, "exit": {"gi-mix": 1}.get(name, 2), "subject": f"{SUBJECT} + mutation {name}",
        "role": "falsifier inner run (expected non-zero)", "log": f"{GD}/falsifiers/falsify-{name}.inner.log",
        "output_sha256": sha(f"{GD}/falsifiers/falsify-{name}.inner.log"),
    })

classification = [
    {"failure": "dialyzer pattern_match machine_experience.ex:539 (closed/5) and :1235 (objects/3)", "class": "subject defect",
     "origin": "V23-M (a2d60a0/d19623e/ffbbee0); absent on origin/main", "repair": "direct pipes over RDF.Graph.description/2 (rdf 3.0.1 specs Description.t(); Description.new(subject) when absent), behavior unchanged", "commit": FIX},
    {"failure": "dialyzer guard_fail xaas.episode.ex:191 hops_anchor/2 `is_map(hops) &&`", "class": "subject defect",
     "origin": "R1-X-COURTS a4c2924 (not in the scan's e999e62 count)", "repair": "drop the dead guard: hops is the map SemanticDrive.verify_hops/1 already admitted", "commit": FIX},
    {"failure": "V26923GoalTest GC23-0 stop-court subprocess + GC23-12 registry (compile_prose --check exited 1 under the pin)", "class": "subject defect (court helper), exposed by the pinned environment",
     "origin": "courts/gi_mix.sh (V23-K) used the caller's mix; ggen_igniter-int _build/test is compiled by its own 1.18.4-otp-27 pin since R1-GI-FMT/R1-GI-PIN", "repair": "gi_mix.sh resolves the drive's graph-side toolchain (`mix xaas.episode --graph-toolchain`, as GC23-8/GC23-9); this is R2-X-TOOLCHAIN item (2) for gi_mix.sh -- bootstrap_court.sh/GC23-1, cargo policy data and typed BUILD_BROKEN exits remain R2-X-TOOLCHAIN's", "commit": FIX},
    {"failure": "V26923GoalTest GC23-0 / GC23-3 court-copy fixtures ('no_llm_env: no policy data')", "class": "subject defect (test fixture)",
     "origin": "R1-X-GUARD 795153d made no_llm_env.sh read priv/no_llm/policy.json; court_repo/1 did not copy it", "repair": "court_repo/1 copies priv/no_llm/policy.json; run_court/3 puts the resolved graph-side toolchain first on PATH for court copies", "commit": FIX},
    {"failure": "ActuationOcelUndoTest :eaddrinuse", "class": "pre-existing (environment-triggered flake)",
     "origin": "hash-derived port 42_777 + phash2(self(), 500) on a host shared with other mix test runs", "repair": "port 0 + ThousandIsland.listener_info/1, as ocel_envelope_avatars_test.exs since 58f37af", "commit": FIX},
    {"failure": "scan candidate: SemanticDrive.build_manifest/2 vsn-1-only match", "class": "subject defect, partly closed before this lane",
     "origin": "d5b8daf (R1-X-COURTS integrate) already read vsn 2 but as element 1 of ANY 3-/4-tuple", "repair": "exactly the two declared Mix.Dep.ElixirSCM shapes are read; any other term (incl. undecodable bytes) is REFUSED(build_manifest_shape) in build_manifest_unused, then the pin applies", "commit": FIX},
    {"failure": "scan candidate: r_projection_test.exs without an absent-validator guard", "class": "environment (hosted runner has no fleet validator)",
     "origin": "RProjection tests call ~/.claude/dfcm/validate_receipt.py", "repair": "per-test @needs_validator guard on the 5 validate/1 tests (the scan's verified patch, applied byte-identically)", "commit": FIX},
    {"failure": "hosted job ci: court_receipt_test.exs:306 (and the same coupling in semantic_receipt_test / successor_law.py)", "class": "environment (host-coupled real courts), subject defect in the tests",
     "origin": "FRI-T3 2393308, V23-H eecc5fe", "repair": "cherry-pick -x of the r2 pre-flight candidate f7dde47 (named skips probing the real precondition), re-verified host vs CI-like", "commit": PICK},
    {"failure": "gate B first command on a fresh _build/dev (postgrex deps not compiled)", "class": "environment", "origin": "fresh _build/dev", "repair": "none (the gate runs on a tree whose dev deps exist; every later run exit 0)"},
    {"failure": "hosted job production cancelled (timeout-minutes 12, C++ NIF compile)", "class": "pre-existing / infrastructure", "origin": "pre-existing on main (scan R2-X-PROD-TIMEOUT)", "repair": "none here: owned by R2-X-PROD-TIMEOUT (and R2-X-IMAGE-CARGO for image-check)"},
]

receipt = {
    "identity": {
        "subject": "R1-X-PIN",
        "repo": "/Users/sac/xaas",
        "repo_slug": "seanchatmangpt/xaas",
        "subject_sha": SUBJECT,
        "base_sha": BASE,
        "branch": "v23/R1-X-PIN",
        "worktree": CWD,
        "work_order": None,
        "tuple_digest": None,
        "tuple_digest_why": "no goal.ttl order for lane R1-X-PIN (grep -c 'WO-R1\\|R1-X' docs/sjira/v26.9.23/goal.ttl -> 0, exit 1): release-defect repair lane; the receipt is not linked by the stop court",
        "base_sha_why": "merge-base(v23/R1-X-PIN, friday/gc-fri-0800) = c68c74d (R1-X-LOCK merged; GUARD b7b3794, COURTS c14a25c, FENCE 6f59676, PGREP 1f12617, DIGEST 3717a7b, LOCK 1e2c373 all ancestors, git merge-base --is-ancestor exit 0 each)",
        "commits_on_subject": [FIX, PICK, SUBJECT],
        "graph_checkout": {"GGEN_IGNITER_DIR": GI, "sha_at_subject_runs": "d6a6e5bd8de1da426ddc26130edfa45bbaf24f61", "sha_at_base_run": "3ed6a7afc51fcfc652cfa72f75680d7fa1543bc8"},
        "prd_ard": "PRD section 12 GC23-11 (exact-subject standing), PR-013 (replay); ARD section 14 (graph-side toolchain), section 20 (failure semantics), section 22 (generated vs handwritten), section 25 (verification ladder); chatman-ce23.md CE23-5 (green exact-head CI: ci_cd.yaml job ci); operator release closure procedure (DRIVER.md): release defect repair on the frozen subject, merges before REL-A3",
    },
    "authority": {
        "actor": "claude-opus-5.5 workflow subagent (lane R1-X-PIN, wave R1c wf_18c25526-098)",
        "ceiling": "CONSTRUCT",
        "grant": "operator release closure procedure via /Users/sac/wt/v26922/v26923/DRIVER.md (17:17 PT R1c = wf_18c25526-098; lanes/wave-R1c.json); hosted CI dispatch and branch push allowed by the wave task after the R1-X-FENCE YAML proof; DRIVER Authority: push branches (never force)",
    },
    "consequence": {
        "commits": [FIX, PICK, SUBJECT],
        "files_changed": files_changed,
        "files_changed_scope": f"git diff --name-only {BASE[:7]} {SUBJECT[:7]} (lane product diff; the receipt commit on top touches receipts/v26.9.23/R1-X-PIN.* only)",
        "receipt_files": ["receipts/v26.9.23/R1-X-PIN.json", "receipts/v26.9.23/R1-X-PIN.gate/"],
        "remote_effects": [
            "git push origin v23/R1-X-PIN (new branch, never forced): 60972f8, then fast-forward to f932e6b",
            "gh workflow run ci_cd.yaml --ref v23/R1-X-PIN: run 35941961752 at 60972f8 (conclusion failure), run 35943406033 at f932e6b (job ci success; run cancelled by job production); publish-image and deploy skipped in both (fence proven before each dispatch)",
        ],
        "generated_vs_handwritten": "no generator owns any touched file (machine_experience.ex, semantic_drive.ex, xaas.episode.ex, gi_mix.sh and the tests are hand-written, already ledgered); HANDWRITTEN.md: one Active note row (append-only) + one Shrunk row (machine_experience.ex -8/+5)",
        "residue": "semantic_drive.ex +manifest shape table/refusal (~30 lines), gi_mix.sh +toolchain resolution (~40 lines incl. comment), test guards; UNSUPPORTED(generator-capability) per the HANDWRITTEN.md note row",
    },
    "toolchain": {
        "elixir": "Elixir 1.20.2 (compiled with Erlang/OTP 28)",
        "erts": "16.4.0.2",
        "elixir_bin": "/Users/sac/.asdf/installs/elixir/1.20.2-otp-28/bin/elixir",
        "mix_bin": "/Users/sac/.asdf/installs/elixir/1.20.2-otp-28/bin/mix",
        "tool_versions_pin": {"elixir": "1.20.2-otp-28", "erlang": "28.5.0.2"},
        "tool_versions_pin_used": True,
        "build": "fresh _build/test and _build/dev compiled under the pin in this worktree (deps/ APFS-cloned from fri/xaas-int, mix.lock identical); manifests {2, {\"1.20.2\", \"28\"}, Mix.SCM.Path, nil}",
        "dialyzer_plt": "priv/plts copied (cp -c) from the scan's OTP 28 PLT as a cache; dialyzer rebuilt it for this tree on the first run",
        "hosted": "setup-beam Elixir 1.20.2 / OTP 28 (erts 16.4.0.2), ubuntu-latest",
        "validator": "python3 3.14.3, jsonschema 4.23.0",
        "log": f"{GD}/subject-f932e6b/toolchain.log",
    },
    "classification": classification,
    "results": {
        "full_suite_run_1": "seed 879900: 1895 passed, 76 excluded, 0 failures (gate A, exit 0)",
        "full_suite_run_2": "seed 684346: 1895 passed, 76 excluded, 0 failures (exit 0)",
        "dialyzer_summary": "Total errors: 29, Skipped: 29, Unnecessary Skips: 0 -- done (passed successfully) (base c68c74d: Total errors: 32, Skipped: 29, exit 2)",
        "empty_home_clause": "Result: 3 passed, 5 skipped",
        "hosted_job_ci": "success at f932e6b: 1796 passed, 99 skipped, 76 excluded; dialyzer 29/29 passed",
    },
    "replay": {
        "durable_location": f"{GD}/ (tracked in git on branch v23/R1-X-PIN; hosted job logs gzip -n)",
        "commands": commands,
    },
    "standing": {
        "value": "ALIVE",
        "derived_from": "exact committed subject f932e6b under the .tool-versions pin: lane gate A/B/C exit 0 (full suite 1895 passed 0 failures, dialyzer 29/29 passed, empty-HOME clause 3 passed 5 skipped) + second full run exit 0 (1895 passed) + 8 revert-mutation falsifiers firing (dialyzer exit 2 at :539/:1235/:191; 5 empty-HOME failures; manifest mutants fail the named pinned tests; GC23-0 REFUSED with the old gi_mix.sh; court copies UNKNOWN without the policy data; :eaddrinuse with the hash port) + hosted exact-head job ci success at f932e6b",
        "scope": "GC23-11 exact-head qualification of xaas and CE23-5 job ci under the pin. ALIVE holds while the lane-touched paths are unchanged from f932e6b. Not in scope and not claimed: the hosted run's overall conclusion (job production cancelled by timeout: R2-X-PROD-TIMEOUT; image-check: R2-X-IMAGE-CARGO), GC23-1/bootstrap_court.sh toolchain and cargo policy (R2-X-TOOLCHAIN)",
        "gate_failure_classification": "see classification; none open at f932e6b",
    },
    "falsifiers": {
        "revert_mutations": [c["summary"] for c in commands if c["role"].startswith("revert-mutation")],
        "chicago_mock_grep": {"at": SUBJECT, "changed_files_matches": 0, "tree_matches_preexisting": 178},
        "llm_on_path": "none: mix, git, python3, gh only; no model API on any executed path",
    },
    "open": [
        "R2-X-TOOLCHAIN: gi_mix.sh half of item (2) landed here with the prescribed resolution; bootstrap_court.sh/GC23-1, cargo as policy data and typed BUILD_BROKEN exits (a graph-side compile failure still maps to the caller's REFUSED) remain",
        "R2-X-DIALYZER (pre-flight c410623): superseded -- this lane closes the same two machine_experience clauses and the xaas.episode guard",
        "successor candidates: the same hash-derived port pattern in test/xaas/telemetry/ocel_forwarder_test.exs:48 and test/xaas/platform/deliver_webhook_test.exs:92 (not reported by any pinned run here); S24-CI-VALIDATOR-VENDOR for the 5 guarded r_projection tests",
    ],
    "witnesses": {
        "why": "runs whose raw exit is non-zero by design or that bound another subject (base, first lane head, falsifier inner checks); the validator admits ALIVE only when every replay.commands exit is 0",
        "runs": witnesses,
    },
}

out = WT / "receipts/v26.9.23/R1-X-PIN.json"
out.write_text(json.dumps(receipt, indent=1, ensure_ascii=False) + "\n")
print(out)
