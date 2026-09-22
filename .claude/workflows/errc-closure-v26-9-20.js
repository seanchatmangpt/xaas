export const meta = {
  name: 'errc-closure-v26-9-20',
  description: 'xaas edition: close every open xaas stream (wave-1 sjira defects, SemanticJiraBridge durability, zcode package, gymact backlog) in isolated worktrees, 3-lens adversarial qualify, one repair round, receipts for serial merge',
  phases: [
    { title: 'Construct', detail: 'one agent per stream in its own worktree cut from the exact xaas base' },
    { title: 'Qualify', detail: 'gate re-run + falsifier + doctrine lens per stream' },
    { title: 'Repair', detail: 'fix-forward on blocker/major qualifier findings' },
  ],
}

const XAAS = '/Users/sac/xaas'
const GYMACT = '/Users/sac/gymact'
const BASE = args.xaasBase
const WT = '/Users/sac/xaas/worktrees/errc'
const WAVE1 = args.wave1Json
const ZCODE_DIR = '/Users/sac/dev/zcode-cli'

const COMMON = `
HARD RULES (all streams):
- First action: cd into the TARGET REPO ABSOLUTE PATH named below, run pwd && git remote -v && git rev-parse --abbrev-ref HEAD and echo it. Wrong repo -> stop and report a mismatch.
- Work ONLY in your own git worktree cut from the exact base SHA given. NEVER edit, merge in, or checkout inside the primary tree (${XAAS}); other sessions and the integrator use it. Do not push, rebase, reset --hard, force anything, or use -X ours/-X theirs. Fix-forward commits only; write commit messages with the Write tool and use git commit -F <file>; confirm with git log -1 --format=%B.
- Cheap build state: cp -cR ${XAAS}/deps ${XAAS}/_build <worktree>/ (APFS clone). Give your stream its OWN test database partition: export MIX_TEST_PARTITION=<stream key, letters+digits only> for every mix test. Postgres has a 200-connection ceiling and several streams run at once: run ONE mix test invocation at a time, never in parallel, and never the full mix test suite unless your task says so (~10 min at low load).
- Chicago-style tests only: real Postgres sandbox, real Ash actions, real files/subprocesses. No Mox/:meck/Mimic/mock libraries or interaction-only assertions. Before finishing run: grep -rn "unittest.mock\\|Mock(\\|MagicMock\\|monkeypatch\\|Mox\\b\\|:meck\\|meck\\." test/ lib/ (Phoenix ConnTest patch("/api/..") verb hits are false positives; name any other hit).
- Ash policy floor: touched resources stay deny-by-default; no hand-edits to generated output; ontology-first (reusable structure is generated; handwritten code is the irreducible residue and is recorded in HANDWRITTEN.md).
- After every Edit/Write re-Read the file to confirm it landed; show git diff --stat.
- Worker protocol: the intended constructor for code edits is the zcode CLI default agent. Resolve its entrypoint from ${ZCODE_DIR}/package.json (name zcode-app-cli, bin.zcode) and run headless: cd <worktree> && timeout 1200 node ${ZCODE_DIR}/<bin.zcode> --cwd . --mode edit --json --prompt="<text>" (use the --prompt=<text> form: a prompt starting with dashes is otherwise parsed as an option). Its shell cannot run mix or git in edit mode ("No permission client configured for Bash"), so you (the supervisor) run every mix/git/verification command yourself. Never widen its permission mode and never attempt zcode login. If zcode is unavailable or produces nothing, construct directly. Report worker_kind honestly: zcode_default_agent | mixed | claude_direct. Never claim zcode did work it did not.
- Status vocabulary: ALIVE only for an observed passing run of the exact subject at the exact head; otherwise PARTIAL_ALIVE / BLOCKED / UNSUPPORTED / UNKNOWN / BUILD_BROKEN. Distinguish pre-existing failures from failures you introduced, with evidence (run the same test at the base SHA in a clean second worktree when in doubt).
- A blocker branches the search graph: quarantine the one irreducible edge with evidence, finish everything else.
- Write your stream notes to docs/streams/<stream key>.md in your worktree (not docs/status-style shared files). Final answer: ONLY the structured receipt.
Wave-1 evidence (per-order results, verifier verdicts and defects, JSON list of {order,result,verdicts}): ${WAVE1}. Orders live under docs/sjira/v26.9.21/ (README.md is the agent protocol). Wave-1 worktrees/branches: /Users/sac/xaas/worktrees/sjira/sj-00N on branch sjira/sj-00N; their raw logs sit beside them as sj-00N.*.log.
`

const RECEIPT = {
  type: 'object',
  properties: {
    stream: { type: 'string' },
    repo: { type: 'string' },
    worktree: { type: 'string' },
    branch: { type: 'string' },
    base_sha: { type: 'string' },
    head_sha: { type: 'string' },
    worker_kind: { type: 'string' },
    files_changed: { type: 'array', items: { type: 'string' } },
    commands: { type: 'array', items: { type: 'string' }, description: 'exact commands with exit code and one-line real result' },
    status: { type: 'string', enum: ['ALIVE', 'PARTIAL_ALIVE', 'BLOCKED', 'UNSUPPORTED', 'BUILD_BROKEN', 'UNKNOWN'] },
    generated_vs_handwritten: { type: 'string' },
    unsupported_or_blocked: { type: 'array', items: { type: 'string' } },
    falsifiers: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
  required: ['stream', 'repo', 'worktree', 'branch', 'base_sha', 'head_sha', 'files_changed', 'commands', 'status', 'summary'],
}

const QUAL = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['pass', 'fail'] },
    issues: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
          description: { type: 'string' },
          evidence: { type: 'string' },
          fix_hint: { type: 'string' },
        },
        required: ['severity', 'description', 'evidence'],
      },
    },
    evidence: { type: 'string' },
  },
  required: ['verdict', 'issues', 'evidence'],
}

const X = (key, branch) => `TARGET REPO (absolute): ${XAAS}   base SHA: ${BASE}
Create your worktree: cd ${XAAS} && git worktree add -b ${branch} ${WT}/${key} ${BASE}   then do all work inside ${WT}/${key}.`

const STREAMS = [
  {
    key: 'sj001-guard', repo: 'xaas', branch: 'errc2/sj001-guard',
    task: `${X('sj001-guard', 'errc2/sj001-guard')}
Bring wave-1 order SJ-001 to a defensible standing. In the worktree run git merge --no-ff sjira/sj-001 (resolve conflicts by reading both sides), then close the verifier defects for SJ-001 recorded in ${WAVE1}: (1) FALSIFIER 1 is reproducibly triggered: Xaas.Ultracode.SemanticWork.admit accepts a descriptor whose graph_digest was altered after admission when the optional admission_digest envelope is omitted (probe B) or altered consistently (probe C); the real graph producer never emits the field, so the production SemanticCrown path is unprotected. Fix the root cause: bind graph_digest to a digest the xaas side recomputes from the admitted source (GgenIgniter.SemanticJira.definition_digest / work_order_digest or the descriptor's own canonical form; read lib/xaas/ultracode/semantic_work.ex, semantic_receipt.ex, semantic_crown.ex and ~/ggen_igniter lib/ggen_igniter/semantic_jira/descriptor.ex) so tamper is REFUSED with a typed reason with or without the envelope; keep envelope-carrying callers backward compatible. (2) Add real tests for probes A (mismatch), B (envelope omitted, digest altered) and C (consistent alteration) and the untampered happy path, in test/xaas/ultracode/semantic_work_test.exs and the e2e test. (3) The e2e courts are fixture shell steps (test -f mix.exs ...); make at least the compile court run a real mix compile in the worktree, and keep the visible skip when /Users/sac/ggen_igniter is absent. (4) Reconcile docs/sjira/v26.9.21/001-xaas-semantic-jira-e2e.md (Status still PARTIAL_ALIVE, DoD boxes unchecked) and receipts/SJ-001.md with what is now observed. DoD: MIX_TEST_PARTITION=sj001g mix test test/xaas/ultracode/semantic_work_test.exs test/xaas/ultracode/semantic_jira_e2e_test.exs test/xaas/ultracode/semantic_tasks_help_test.exs exits 0, then one run of mix test test/xaas/ultracode.`,
  },
  {
    key: 'sj004-registry', repo: 'xaas', branch: 'errc2/sj004-registry',
    task: `${X('sj004-registry', 'errc2/sj004-registry')}
Bring wave-1 order SJ-004 (docs/sjira/v26.9.21/004-resource-adoption-registry-exemptions.md) to observed standing. git merge --no-ff sjira/sj-004 in the worktree; test/xaas/semantics/registry_test.exs conflicts with main (main already carries an @pending exemption list plus a one-line change from errc/xaas-closure): reconcile by reading both sides. The wave-1 worker's DoD reached PARTIAL_ALIVE only because the full mix test could not pass under host load (61 then 41 failures, all DBConnection pool exhaustion or eaddrinuse). Do NOT run the full suite. Prove instead: (a) mix compile --warnings-as-errors exit 0; (b) MIX_TEST_PARTITION=sj004r mix test test/xaas/semantics test/xaas/operations test/xaas/coupling test/xaas/ledger exits 0 (list what you ran); (c) every resource the order adopted into Xaas.Resource is admitted by Registry.admit and the @pending list in registry_test.exs shrinks to exactly the genuinely-exempt library resources (Accounts.Token.RevokeNonce and the .Version paper-trail modules) with reasons; (d) deny-by-default policies unchanged on touched resources (diff proof) and mix ash_postgres.generate_migrations --check (or the repo's equivalent) reports no pending migration; (e) compare any failing test against the same test at base ${BASE} in a scratch worktree to classify pre-existing vs introduced. Update the order file Status and receipts to the observed standing.`,
  },
  {
    key: 'sj003-plugin', repo: 'xaas', branch: 'errc2/sj003-plugin',
    task: `${X('sj003-plugin', 'errc2/sj003-plugin')}
Finish wave-1 order SJ-003 (docs/sjira/v26.9.21/003-handwritten-paydown-zcode-plugin.md: pay down handwritten zcode plugin via ggen packs). git merge --no-ff sjira/sj-003. Wave-1 worker delivered repo-local packs (priv/zcode_plugin/packs/zcode-plugin-pack, ultracode-actuation-lease-pack) and a projection test but the literal DoD (ggen sync && git diff --exit-code && mix test) was never observed: root-level ggen sync run was killed after 36+ minutes (UNKNOWN). Diagnose with a bounded hypothesis (which subprocess/dir is it walking? use ps/sample/lsof on a 5-minute-capped run, ggen --help for a scoped manifest option, and ~/ggen-marketplace/packs for a pack that already covers this), find the lawful scoped invocation that completes (e.g. ggen sync against priv/zcode_plugin/ggen.toml), then observe: sync exits 0, git diff --exit-code is clean after sync (idempotent), test/xaas/zcode_plugin passes, HANDWRITTEN.md ledger rows match reality. If sync cannot be made to finish within 10 minutes, record BLOCKED with the exact hung process evidence and prove the same templates render through the alternative lawful path; do not claim ALIVE without the observed run. Never use zcode --mode yolo.`,
  },
  {
    key: 'sj007-ard', repo: 'xaas', branch: 'errc2/sj007-ard',
    task: `${X('sj007-ard', 'errc2/sj007-ard')}
Correct wave-1 order SJ-007 (ash_atlassian target, BLOCKED order, deliverable is the ARD). git merge --no-ff sjira/sj-007. The qualifier refuted it: (1) standing PARTIAL_ALIVE was self-declared while required_courts=["tests"] was never run: real GgenIgniter.SemanticJira.promote refuses with {:promotion_refused,[:courts]}. Either run the order's declared courts for real and record court_results, or set the honest standing the promotion function admits, in the order file, index.json and receipts. (2) ARD claim "no pack projects AshAi tool exposure" is wrong: packs/elixir-mcp-a2a-pack (AshAi.Mcp.Router) and packs/xaas-ash-core-pack/xaas-ash-build-mcp-GENERATED.sh (ash_ai.gen.mcp) exist in ~/ggen-marketplace; add them to the REUSE table and survey residue against them. (3) ARD claims no local ~/ash_atlassian, which exists with a zero-commit .git, ggen.toml, gates, templates and lib: reconcile the ARD with what is actually there (read-only). (4) stale receipts: sj-007-verification.json (says SJ-010..012 admission not executed and a commitmsg file that does not exist), sj-007-manufacture.json (hand-rendered claim, malformed worktree path), .gen-sj007.py docstring and the 007 History lines. Regenerate through docs/sjira/v26.9.21/generate.py where the order text is generated (re-admit via admit.exs in ~/ggen_igniter and re-run SA2A admit through Xaas.Sa2a.Bridge if a digest changes; record receipts). No lib/ or test/ changes expected.`,
  },
  {
    key: 'sj009-receipt-flakes', repo: 'xaas', branch: 'errc2/sj009-flakes',
    task: `${X('sj009-receipt-flakes', 'errc2/sj009-flakes')}
Correct wave-1 order SJ-009 (ash_ai dependency retest; docs-only branch sjira/sj-009). git merge --no-ff sjira/sj-009. Verifier findings (${WAVE1}): ALIVE not independently reproduced: full mix test runs exited 2 under host load (Ultracode.EngineTest:281 sandbox worker_crashed, ActuationOcelUndoTest:161 :eaddrinuse, DBConnection pool errors). Main already contains commit 1ac5942 which root-caused two EngineTest slot-fill flakes (docs/streams/xaas-closure.md): verify whether EngineTest:281 still flakes (run it 10 times sequentially with --max-cases 1, report pass/fail counts). Root-cause and fix ActuationOcelUndoTest:161 :eaddrinuse at its source (an explicit fixed port used by a real listener: bind port 0 and read the assigned port) with a permanent guard, then run that file 5 times. Fix the receipt: standing for the dependency edge is COMPATIBLE (no failing ash_ai/req_llm/finch edge observed across runs) but suite-green is PARTIAL_ALIVE unless you observe one full mix test exit 0 at your head (a full run is allowed for this stream only; do it exactly once, after the fixes, with MIX_TEST_PARTITION=sj009f, and only if uptime load average is under 12; if not, wait with an until-loop). Copy the worker's raw logs from /Users/sac/xaas/worktrees/sjira/sj-009*.log into docs/sjira/v26.9.21/receipts/sj-009/ and content-hash them in SJ-009.verification-manifest.json so replay is verifiable from the branch. Fix the sentence claiming Claude contributed all execution (the zcode agent ran the chicago court). SA2A replay proves manifest self-consistency only: say so.`,
  },
  {
    key: 'bridge-integrate', repo: 'xaas', branch: 'errc2/bridge-integrate',
    task: `${X('bridge-integrate', 'errc2/bridge-integrate')}
Make branch errc/semantic-jira-bridge (12 commits: Xaas.Ultracode.SemanticJiraBridge, LogLock, verifier verdict-source hardening, 9 test files, docs/streams/semantic-jira-bridge.md) mergeable to main durably. git merge --no-ff errc/semantic-jira-bridge in the worktree (resolve conflicts by reading both sides; main moved 9 commits). Blocker: that branch pins ggen_igniter in mix.exs by absolute PATH to a detached scratch worktree (/Users/sac/ggen_igniter-wt2/xaas-dep) that will be deleted. Choose the most durable source that contains the Semantic Jira modules (GgenIgniter.SemanticJira Reconciler/TransitionLog/Descriptor/frontier_from_events, SemanticA2A) AND the event-digest fix consumed by commit c4216ef: check in order (1) hex: mix hex.info ggen_igniter for a published version >= 26.9.20 covering those modules (verify by fetching the package into a scratch dir and grepping), (2) a git dependency pinned by ref to a pushed commit of the ggen_igniter repo (check git -C /Users/sac/ggen_igniter remote -v, git branch -r --contains <sha>), (3) only as a last resort a path dependency on the primary checkout /Users/sac/ggen_igniter if that tree's HEAD contains the modules, recording UNSUPPORTED(durable-source) with the exact missing publish step. Do not commit anything to ggen_igniter and do not push. Then prove: mix deps.get, mix compile --warnings-as-errors, mix format --check-formatted, and MIX_TEST_PARTITION=bridge mix test on every test/xaas/ultracode/semantic_jira_bridge_*_test.exs, log_lock_test.exs, verifier_verdict_source_test.exs and the existing test/xaas/ultracode/semantic_* tests. The commit 12021c0 says 12 tests red by design: confirm the later repair commits turned them green, and name any that are still red with the reason. Update docs/streams/semantic-jira-bridge.md residuals to the observed truth.`,
  },
  {
    key: 'zcode-package-verify', repo: 'xaas', branch: 'errc2/zcode-package',
    task: `${X('zcode-package-verify', 'errc2/zcode-package')}
Verify and land branch auto/zcode-package (commit 5d8386f, never test-verified): Xaas.Ultracode.ZcodePackage admits ${ZCODE_DIR}/package.json (name must be zcode-app-cli; bin.zcode resolved inside the CLI dir and a regular file; engines.node parsed only as >=X.Y.Z), Dispatch.resolve_opts uses it (zcode_bin, zcode_version, node floor check), scripts/xaas-glm-failover-dispatcher.sh has zcode_package_preflight, test/support/fake-node.sh answers --version. git merge --no-ff auto/zcode-package in the worktree. Then prove with real runs: mix compile --warnings-as-errors; mix format --check-formatted; MIX_TEST_PARTITION=zpkg mix test test/xaas/ultracode/zcode_package_test.exs test/xaas/ultracode/dispatch_test.exs test/xaas/ultracode/wave_loop_test.exs (the zcode_package test includes one against the REAL ${ZCODE_DIR}; if the real CLI needs a Node version the machine lacks, capture the typed {:node_too_old ...} result); bash -n on the dispatcher; a run of the dispatcher preflight against the real CLI and against a bad dir (typed failure, exit 127). Fix forward any failure. Also add ProviderHealth coupling: a small Xaas.Ultracode.ProviderHealth (or extend an existing provider-health module if one exists: grep first) that calls ZcodePackage.check/2 and reports {:ok, %{zcode_version, zcode_bin, node_version}} | {:error, typed} so the autonomic loop can gate leases on it; test it against the real CLI dir and a bad dir. Add the HANDWRITTEN.md row.`,
  },
  {
    key: 'sj008-gymact', repo: 'gymact', branch: 'errc2/sj008-gymact',
    task: `TARGET REPO (absolute): ${GYMACT}   (repository seanchatmangpt/gymact). Wave-1 branch sjira/sj-008 is checked out at /Users/sac/xaas/worktrees/sjira/sj-008 (head 333aeb5f). Create your own worktree from that head: cd ${GYMACT} && git worktree add -b errc2/sj008-gymact ${WT}/sj008-gymact 333aeb5f (this repo, not xaas: ignore the xaas cp -cR and MIX rules; use the repo's own .venv by absolute path, /Users/sac/gymact/.venv or the sj-008 worktree's .venv, and never install packages system-wide). Order file: /Users/sac/xaas/docs/sjira/v26.9.21/008-gymact-open-backlog.md. The wave-1 worker documented the backlog but left the order-level pytest red: 9 failures plus 1 collection error (cube_container_counter) in the provisioned env, and GYMACT-5 (test_verify_replay imports a half-initialised, module-level-skipped test_terraform_plan) and GYMACT-6 (unclosed dspy/diskcache sqlite connection and event loop blamed on unrelated tests under filterwarnings=error) open because they sat outside path_scope. The Definition of done is the goal: extend the scope to tests/ and fixtures as needed, root-cause each red test (real fixes: proper fixtures/teardown that close the sqlite connection and event loop, import structure that does not depend on a skipped module, the missing dependency or module behind the cube_container_counter collection error), never delete or weaken an assertion and never add skips to hide a failure (a visible named skip is only allowed for a genuinely absent external service). Chicago style: no mock libraries. DoD: the order's own pytest command exits 0 without GYMACT_ALLOW_DEGRADED_STANDIN, observed at the final head. Write the stream note to docs/streams/sj008-gymact.md in the gymact worktree and update the backlog doc status rows honestly.`,
  },
]

const LANES = [
  ['sj001-guard', 'sj003-plugin', 'sj008-gymact'],
  ['bridge-integrate', 'sj007-ard', 'sj009-receipt-flakes'],
  ['sj004-registry', 'zcode-package-verify'],
]

const byKey = Object.fromEntries(STREAMS.map((s) => [s.key, s]))

const constructPrompt = (s) =>
  `${COMMON}\nSTREAM: ${s.key}   BRANCH: ${s.branch}\n\nTASK:\n${s.task}\n\nWhen done: all work committed on ${s.branch} in your worktree (git status clean), receipt returned with real command output summaries.`

async function runStream(s) {
  const receipt = await agent(constructPrompt(s), { label: `build:${s.key}`, phase: 'Construct', schema: RECEIPT })
  if (!receipt) return { stream: s.key, receipt: null, verdict: 'BUILD_FAILED', issues: [] }
  const base = `TARGET: worktree ${receipt.worktree} (repo ${receipt.repo}, branch ${receipt.branch}, head ${receipt.head_sha}). cd there first, run pwd, git status, git log --oneline -8, echo them. You are a QUALIFIER: do not trust the builder's receipt (${JSON.stringify(receipt.summary)}); re-derive by running commands. Add commits ONLY for failing falsifier tests or trivial clearly-labelled fixes; otherwise report. Never push, rebase, reset. Run ONE mix test invocation at a time with your own MIX_TEST_PARTITION (Postgres has a 200-connection ceiling shared with other streams). Never run the full mix test. Stream task for reference:\n${s.task}\n`
  const lenses = [
    `LENS gate: independently re-run: mix compile --warnings-as-errors; mix format --check-formatted; the stream's own tests and the pre-existing suites touching modified files; the mock grep (grep -rn "unittest.mock\\|Mock(\\|MagicMock\\|monkeypatch\\|Mox\\b\\|:meck\\|meck\\." test/ lib/, Phoenix patch("/api") verb hits excepted). For python (gymact) streams: the order's pytest command instead. Paste real outputs. Verify every failure against the base in a scratch checkout before calling it introduced. verdict=fail on any introduced failure or any claimed-ALIVE without an observed run at this head.`,
    `LENS falsifier: build the most adversarial concrete scenarios against the stream's central claim (tampered digests/receipts, second-run idempotence, stale state, bad input, missing external tools, the exact defect the stream was created to fix reintroduced) and run them for real. If you break the claim add a failing test on a commit labelled test(falsifier) and report it as a blocker with the failing output. If you cannot break it after a serious attempt, list what you tried.`,
    `LENS doctrine: check the diff (git diff ${BASE}..HEAD, or the base named in the receipt) against repo doctrine: Chicago tests, Ash deny-by-default policy floor, HANDWRITTEN.md ledger rows honest, no over-claiming in docs/receipts/order files (ALIVE only with an observed run at this head; worker_kind matches what really happened), sensitive resources not newly exposed, fix-forward commit hygiene with messages landed correctly, no secrets, no leftover debug/TODO, no edits to generated output. Flag every over-claim with evidence.`,
  ]
  const quals = (await parallel(lenses.map((l, i) => () => agent(`${base}\n${l}`, { label: `qual${i}:${s.key}`, phase: 'Qualify', schema: QUAL })))).filter(Boolean)
  const issues = quals.flatMap((x, i) => (x.issues || []).map((it) => ({ ...it, lens: i })))
  const blocking = issues.filter((i) => i.severity !== 'minor')
  if (!blocking.length) return { stream: s.key, receipt, verdict: 'pass', issues, repaired: false }
  const fixed = await agent(
    `${COMMON}\nYou are the REPAIR agent for stream ${s.key}. TARGET: worktree ${receipt.worktree} (repo ${receipt.repo}, branch ${receipt.branch}). cd there, pwd, git status. Fix-forward ONLY. Resolve every blocker/major issue below with a root-cause fix and a permanent guard, re-run the failing check and the stream's narrow suites, the mock grep and format/compile. A false positive must be proven with a run. Issues:\n${JSON.stringify(blocking, null, 1)}\nOriginal task:\n${s.task}\nReturn an updated receipt (new head_sha, all commands, honest status).`,
    { label: `repair:${s.key}`, phase: 'Repair', schema: RECEIPT },
  )
  return { stream: s.key, receipt: fixed || receipt, verdict: fixed ? 'repaired' : 'repair_failed', issues, repaired: !!fixed }
}

// Bounded width: 3 lanes drain their own queues serially (Postgres ceiling, host load).
const laneResults = await parallel(LANES.map((keys) => async () => {
  const out = []
  for (const k of keys) out.push(await runStream(byKey[k]))
  return out
}))

const flat = laneResults.filter(Boolean).flat()
log(`streams: ${flat.map((r) => `${r.stream}=${r.verdict}`).join(' ')}`)
return flat
