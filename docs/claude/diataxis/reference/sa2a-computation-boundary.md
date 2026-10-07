# SA2A computation boundary

XaaS does not make an AI or agent framework the control-plane primitive.

The BEAM-side computation boundary accepts runtime-neutral artifacts and candidate claims from ONNX, Nx/Axon, PyTorch, scikit-learn, LLMs, rules, SPARQL, FOND, HDDL, WASM, native code, or humans.

A ComputationArtifact names the stable public capability separately from the runtime used to implement it (`Xaas.Semantics.ComputationArtifact`, `lib/xaas/semantics/computation.ex:1`; closed runtime allowlist at `computation.ex:11`). A ComputationClaim is always CANDIDATE and cannot authorize actuation (`Xaas.Semantics.ComputationClaim`, `computation.ex:113`; `new/1` refuses any other standing and hard-codes `authorizes_actuation: false`, `computation.ex:154-164`). PlanningAdvice can reorder an externally supplied formal planner frontier but cannot add or remove members of that frontier (`Xaas.Semantics.PlanningAdvice`, `computation.ex:202`; `order_formal/2` filters advice candidates to the formal set and appends any unadvised formal refs unchanged, `computation.ex:262-278`).

Consequential mutation remains exclusively:

public semantic projection -> admission -> durable intent -> prepared receipt -> Ash.Reactor DO -> sealed receipt -> replay.

The new computation modules (`lib/xaas/semantics/computation.ex`) do not call Xaas.Actuation, manufacture authority evidence, or persist an Ash resource. The only module in the SA2A surface that crosses into `Xaas.Actuation.run/4` is `Xaas.Sa2a.Executor` (`lib/xaas/sa2a/executor.ex:59`), which is the admitted control-plane route, not a computation module. If persistence is later required, it must be manufactured from the repository's canonical ontology/ggen path rather than by hand-writing a second semantic source.

Route conservation is the typed seam proving a work-order tuple survives the sJira → SA2A → XaaS hops unmutated. `Xaas.Sa2a.Route` (`lib/xaas/sa2a/route.ex`) normalizes the three representations a work order takes — the sJira `wo.json` row, the SA2A task (one `kind: "data"` input part with schema `semantic-jira/route-tuple/v1`, `route.ex:48`, `route.ex:276-291`), and the XaaS semantic epoch contract (re-admitted through `Xaas.Ultracode.SemanticWork.admit/1`, `route.ex:232-243`; `lib/xaas/ultracode/semantic_work.ex:207`) — to one canonical tuple (`Route.tuple/1`), digested as sha256 over canonical JSON with sorted keys and `exclusions` sorted (`Route.digest/1`, `route.ex:134-148`).

`Route.resolve/1` maps a `recipe:<id>` capability through the `config :xaas, :ultracode_construction_recipes` registry (`config/config.exs:477`), else `{:refused, :unregistered_capability}` (`route.ex:165-174`). `Route.conserve/3` refuses any digest mismatch as `broken_term: "admission_vacuous"` naming the first differing contract field (`route.ex:187-202`): a hop that changed the tuple would make the upstream admission say nothing about what executes. The module grants no authority, selects no frontier, and actuates nothing.

This preserves the Blue River Dam boundary: model/runtime implementations are replaceable downstream computation; semantics, admission, authority, consequence, and receipts remain upstream control.
