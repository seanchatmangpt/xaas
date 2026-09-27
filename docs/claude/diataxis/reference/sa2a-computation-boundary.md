# SA2A computation boundary

XaaS does not make an AI or agent framework the control-plane primitive.

The BEAM-side computation boundary accepts runtime-neutral artifacts and candidate claims from ONNX, Nx/Axon, PyTorch, scikit-learn, LLMs, rules, SPARQL, FOND, HDDL, WASM, native code, or humans.

A ComputationArtifact names the stable public capability separately from the runtime used to implement it. A ComputationClaim is always CANDIDATE and cannot authorize actuation. PlanningAdvice can reorder an externally supplied formal planner frontier but cannot add or remove members of that frontier.

Consequential mutation remains exclusively:

public semantic projection -> admission -> durable intent -> prepared receipt -> Ash.Reactor DO -> sealed receipt -> replay.

The new computation modules do not call Xaas.Actuation, manufacture authority evidence, or persist an Ash resource. If persistence is later required, it must be manufactured from the repository's canonical ontology/ggen path rather than by hand-writing a second semantic source.

Route conservation is the typed seam proving a work-order tuple survives the sJira → SA2A → XaaS hops unmutated. `Xaas.Sa2a.Route` (`lib/xaas/sa2a/route.ex`) normalizes the three representations a work order takes — the sJira `wo.json` row, the SA2A task (one data part with schema `semantic-jira/route-tuple/v1`), and the XaaS semantic epoch contract (re-admitted through `Xaas.Ultracode.SemanticWork.admit/1`) — to one canonical tuple (`Route.tuple/1`), digested as sha256 over canonical JSON (`Route.digest/1`).

`Route.resolve/1` maps a `recipe:<id>` capability through the `config :xaas, :ultracode_construction_recipes` registry, else `{:refused, :unregistered_capability}`. `Route.conserve/3` refuses any digest mismatch as `broken_term: "admission_vacuous"`: a hop that changed the tuple would make the upstream admission say nothing about what executes. The module grants no authority, selects no frontier, and actuates nothing.

This preserves the Blue River Dam boundary: model/runtime implementations are replaceable downstream computation; semantics, admission, authority, consequence, and receipts remain upstream control.
