import json, os
HERE=os.path.dirname(os.path.abspath(__file__))
OUT=os.environ.get("SJIRA_OUT",HERE)
# Observed standing is a generator INPUT, not a hand edit of the generated order file:
# <STANDING>/NNN.json = {standing, standing_note?, repository_suffix?, done:[acceptance idx], receipts:"NNN.receipts.md"}
STANDING=os.environ.get("SJIRA_STANDING",os.path.join(HERE,"standing"))
X=("seanchatmangpt/xaas","8e72cfcb85bd901ad067589295598eb7580a1442")
A=("seanchatmangpt/autofde-lab","2f4825a232bfea543764d13f3b75fcb0ff33da1f")
G=("seanchatmangpt/gymact","4ab72e685302aa591f65fecad0ec73129ecd3589")
COURTS=["compile","tests","chicago_no_mocks"]
def wo(n,slug,title,repo,standing,desc,evidence,acceptance,falsifiers,dod,scope,deps=(),proj=("jira","verification","receipt"),courts=COURTS,ceiling="EXECUTED_VERIFIED"):
    r,sha=repo
    return dict(n=n,slug=slug,md=dict(identity=f"SJ-{n:03d}",title=title,description=desc,subject=slug,repository=r,base_sha=sha,
      standing=standing,evidence_ceiling=ceiling,promotion_rule="verified_by_required_courts_then_receipted",
      replay_identity=f"sjira-v26.9.21-sj-{n:03d}",required_courts=courts,required_evidence=["command_exit_codes","real_output"],
      acceptance=acceptance,falsifiers=falsifiers,projections=list(proj),
      dependencies=[dict(upstream=f"SJ-{d:03d}",type="requiresReceipt") for d in deps],
      authority_requirement="NONE",path_scope=scope,required_receipt_classes=["manufacture","verification"]),
      evidence=evidence,dod=dod)
W=[
wo(1,"xaas-semantic-jira-e2e","xaas consumes a real Semantic Jira WorkOrder end to end",X,"PARTIAL_ALIVE",
 "xaas already shells to `mix semantic_jira.*` (semantic_crown.ex, mix xaas.semantic.materialize/receipt), but no committed proof shows an admitted WorkOrder from this directory flowing admit -> materialize -> receipt -> replay. Produce that proof.",
 ["`grep -rn semantic_jira lib/` hits lib/xaas/ultracode/semantic_crown.ex:18, lib/mix/tasks/xaas.semantic.{materialize,receipt}.ex","autofde-lab/docs/2026-09-21-zero-human-factory-standing.md rated this UNSUPPORTED; that grep only matched `sJira` spellings, not `semantic_jira.`"],
 ["one SJ-00x work order from this dir is admitted by GgenIgniter.SemanticJira.admit_work_order/1","`mix xaas.semantic.materialize` accepts it and `mix xaas.semantic.receipt` seals a receipt","replay of the receipt reproduces the same digest"],
 ["materialize accepts a WorkOrder whose digest was altered after admission","receipt seals without the required courts passing"],
 "cd ~/xaas && mix test test/xaas/ultracode && mix xaas.semantic.materialize --help",["lib/xaas/ultracode/**","lib/mix/tasks/xaas.semantic.*","test/xaas/ultracode/**","docs/sjira/**"]),
wo(2,"zcode-ocel-pack-consumer","zcode-ocel-pack gets a real consumer",X,"UNSUPPORTED",
 "ggen_igniter renders `zcode-ocel-pack` constants (OBJECT_TYPES/EVENT_TYPES/PRIMARY_OBJECT/QUALIFIERS/TRANSITIONS) but neither xaas nor autofde-lab references them. Wire xaas's zcode plugin/OCEL emission (Xaas.Telemetry.OcelAshEmitter, priv/zcode_plugin) to the generated registry so event types are generated, not hand-listed.",
 ["`grep -rn 'zcode-ocel-pack' lib test ~/autofde-lab/src` -> zero matches (verified 2026-09-21)"],
 ["a generated ocel registry module is rendered into xaas via ggen sync","OcelAshEmitter/zcode plugin validate event types against it","a test asserts an unknown event type is refused"],
 ["emitter accepts an event type absent from the generated registry"],
 "cd ~/xaas && ggen sync && mix test test/xaas/telemetry",["lib/xaas/generated/**","lib/xaas/telemetry/**","priv/zcode_plugin/**","ontology/**"],deps=(1,),proj=("jira","machine","verification","receipt")),
wo(3,"handwritten-paydown-zcode-plugin","Pay down HANDWRITTEN.md: promote zcode plugin templates into zcode-plugin-pack",X,"PARTIAL_ALIVE",
 "Wave manufactured-ratio was 0% (docs/ultracode/PROGRESS.md). Templates/generator under priv/zcode_plugin and the lease/controller rows in HANDWRITTEN.md still name owner packs that do not render them. Promote the contract-clean templates into zcode-plugin-pack and admit ultracode-actuation-lease-pack; delete the corresponding HANDWRITTEN.md rows.",
 ["HANDWRITTEN.md Active rows: lease.ex, execution_fabric_controller.ex, xaas.receipts.ex, priv/zcode_plugin/templates/*.tmpl","PROGRESS.md: 'Ratio = 0%, honestly'"],
 ["ggen renders the plugin files from the pack","HANDWRITTEN.md has strictly fewer Active rows","`git diff` of rendered output is empty on re-sync"],
 ["a rendered file differs from the checked-in one","HANDWRITTEN.md row removed while the file is still hand-edited"],
 "cd ~/xaas && ggen sync && git diff --exit-code && mix test",["HANDWRITTEN.md","priv/zcode_plugin/**","lib/xaas/generated/**"],proj=("jira","machine","verification","receipt")),
wo(4,"resource-adoption-registry-exemptions","Adopt Xaas.Resource on the registry-exempt resources",X,"PARTIAL_ALIVE",
 "test/xaas/semantics/registry_test.exs carries a disclosed `@pending` exemption list (CouplingRun, EventLog, AutofdePlannerCacheHotset/CacheStats/Candidate/Catalog/Match; plus library-generated RevokeNonce and *.Version). Migrate the seven owned resources to `use Xaas.Resource` (base_resources) and shrink the list to library-generated only.",
 ["commit on main: 'exempt library-generated resources in registry test'","`Xaas.Resource` is the configured base_resources entry in config/config.exs"],
 ["`@pending` contains only RevokeNonce","`mix test test/xaas/semantics` passes","deny-by-default policy floor preserved on each touched resource"],
 ["a migrated resource gains an allow-all policy","projection admission passes but ontology_projection_hash is nil"],
 "cd ~/xaas && mix test test/xaas/semantics && mix test",["lib/xaas/coupling/**","lib/xaas/ledger/**","lib/xaas/operations/autofde_planner_*","test/xaas/semantics/registry_test.exs"]),
wo(5,"zoe-simulation-reconcile","Reconcile the two ZOE event simulations",X,"PARTIAL_ALIVE",
 "Two independent implementations landed from parallel branches: Xaas.Zoe.EventSimulation (dfcm, whole-event obligations) and Xaas.Zoe.EventSimulationZoe (agent contract/0 + simulate/2). Only the latter backs XaasWeb.A2A.ZoeEventSimulationAgent. Merge into one module preserving both test suites' assertions.",
 ["lib/xaas/zoe/event_simulation.ex, lib/xaas/zoe/event_simulation_zoe.ex","lib/xaas_web/a2a/zoe_event_simulation_agent.ex calls EventSimulationZoe"],
 ["single Xaas.Zoe.EventSimulation module","both test files' assertions pass against it (test/xaas/zoe/*, test/xaas_web/a2a/zoe_event_simulation_agent_test.exs)"],
 ["either suite loses an assertion during the merge"],
 "cd ~/xaas && mix test test/xaas/zoe test/xaas_web/a2a",["lib/xaas/zoe/**","lib/xaas_web/a2a/**","test/xaas/zoe/**","test/xaas_web/a2a/**"]),
wo(6,"ecosystem-standing-foldin","Fold SA2A / Semantic Jira / zcode findings into autofde-lab ecosystem-standing",A,"PARTIAL_ALIVE",
 "docs/ecosystem-standing.md names none of SA2A, XaaS, zcode, ggen_igniter, Semantic Jira. Add rows using the standing vocabulary, each with a reproducible command (sa2a bridge: `pytest tests/beam/` = 4 passed; SJ-001/SJ-002 standings from this directory).",
 ["autofde-lab/docs/2026-09-21-zero-human-factory-standing.md"],
 ["ecosystem-standing.md has a row per system with standing + command","no row is ALIVE without an observed run"],
 ["a row claims ALIVE with no command"],
 "cd ~/autofde-lab && .venv/bin/python -m pytest tests/beam/ -v",["docs/ecosystem-standing.md"],deps=(1,2),proj=("jira","executive","receipt"),courts=["tests"],ceiling="OBSERVED"),
wo(7,"ash-atlassian-target","Scope the ash_atlassian migration target",X,"BLOCKED",
 "The whitepaper's Atlassian -> ash_atlassian migration has no target: ~/ash_atlassian does not exist and ~/atlassian is an empty stub. BLOCKED:NO_TARGET_PACKAGE. Deliverable is a scoped ARD (resources, ontology source, generator route via ggen-marketplace) so the blocker becomes a buildable order.",
 ["`ls ~/ash_atlassian` -> No such file or directory","`ls ~/atlassian` -> one stub entry (verified 2026-09-21)"],
 ["an ARD under docs/sjira/v26.9.21/ names the ontology source and pack route","a follow-up work order set is emitted as new SJ files"],
 ["ARD proposes hand-written resources where a pack could generate them"],
 "test -f docs/sjira/v26.9.21/ash-atlassian-ard.md",["docs/sjira/**"],proj=("jira","ard","prd","hddl"),courts=["tests"],ceiling="CONSTRUCTED"),
wo(8,"gymact-open-backlog","Close the four open gymact backlog tickets",G,"PARTIAL_ALIVE",
 "docs/2026-08-13-gymact-jira-backlog.md: GYMACT-1 (dev_portfolio not registered) and GYMACT-2 (false docstring) marked In Progress; GYMACT-3 (CLAUDE.md cites missing STATUS.md / ecosystem-standing.md) and GYMACT-4 (8 pytest failures, unreproduced) Open. Re-verify each with a real command, fix what still reproduces, update the backlog Status.",
 ["4 tickets in the backlog file (verified by grep 2026-09-21)"],
 ["each ticket's Definition of done command passes","backlog Status fields updated to Done/Not-reproducible with evidence"],
 ["GYMACT-4 closed without a repeated full pytest run"],
 "cd ~/gymact && python -m pytest -q",["src/gymact/gyms/**","docs/**","CLAUDE.md"],proj=("jira","verification","receipt")),
wo(9,"ash-ai-dependency-retest","Retest the ash_ai dependency probe against current deps",X,"UNKNOWN",
 "The probe branch's tip is preserved at tag archive/probe-ash-ai-dependency-retest-fa744ec (superseded-merged). Re-run the retest on current main: add ash_ai in a worktree, `mix deps.get && mix compile && mix test`, record whether the earlier incompatibility persists.",
 ["tag archive/probe-ash-ai-dependency-retest-fa744ec on origin"],
 ["a receipt states COMPATIBLE or the exact failing dependency edge"],
 ["result reported without running deps.get + compile + test"],
 "cd <worktree> && mix deps.get && mix compile && mix test",["mix.exs","mix.lock"],proj=("jira","verification","receipt")),
]
def observed(w):
    """Overlay observed standing/ticks/receipts for one order. ALIVE requires every DoD item ticked and a receipts file."""
    p=os.path.join(STANDING,f"{w['n']:03d}.json")
    if not os.path.exists(p):
        return dict(done=[],note=None,suffix="",receipts="")
    o=json.load(open(p))
    n=len(w['md']['acceptance'])
    done=sorted(set(o.get("done",[])))
    assert all(isinstance(i,int) and 0<=i<n for i in done), f"{p}: done index outside acceptance[0..{n})"
    receipts=open(os.path.join(STANDING,o["receipts"])).read() if o.get("receipts") else ""
    if o["standing"]=="ALIVE":
        assert len(done)==n, f"{p}: ALIVE with {n-len(done)} unticked DoD item(s)"
        assert receipts.startswith("## Receipts"), f"{p}: ALIVE without a receipts section"
    w['md']['standing']=o["standing"]
    return dict(done=done,note=o.get("standing_note"),suffix=o.get("repository_suffix",""),receipts=receipts)
idx=[]
for w in W:
    fn=f"{w['n']:03d}-{w['slug']}.md"
    ov=observed(w)
    m=w['md']
    body=f"---\n{json.dumps(m,indent=2)}\n---\n\n# {m['identity']}: {m['title']}\n\n- **Standing**: {m['standing']}{' ('+ov['note']+')' if ov['note'] else ''}\n\n## Status\n{m['standing']}\n- **Repository**: {m['repository']} @ `{m['base_sha'][:7]}`{ov['suffix']}\n\n## Description\n{m['description']}\n\n## Evidence\n"+"".join(f"- {e}\n" for e in w['evidence'])+"\n## Definition of done\n"+"".join(f"- [{'x' if i in ov['done'] else ' '}] {a}\n" for i,a in enumerate(m['acceptance']))+f"\nRunnable check:\n\n```sh\n{w['dod']}\n```\n\n## Falsifiers\n"+"".join(f"- {f}\n" for f in m['falsifiers'])+("\n"+ov['receipts'] if ov['receipts'] else "")
    open(f"{OUT}/{fn}","w").write(body)
    idx.append(dict(id=m['identity'],path=fn,standing=m['standing'],repository=m['repository'],dependencies=[d['upstream'] for d in m['dependencies']]))
json.dump(idx,open(f"{OUT}/index.json","w"),indent=2)
json.dump([w['md'] for w in W],open(os.environ.get("WO_JSON","/tmp/wo.json"),"w"))
print(len(W))
