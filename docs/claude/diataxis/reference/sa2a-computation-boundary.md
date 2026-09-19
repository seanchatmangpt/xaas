# SA2A computation boundary

XaaS does not make an AI or agent framework the control-plane primitive.

The BEAM-side computation boundary accepts runtime-neutral artifacts and candidate claims from ONNX, Nx/Axon, PyTorch, scikit-learn, LLMs, rules, SPARQL, FOND, HDDL, WASM, native code, or humans.

A ComputationArtifact names the stable public capability separately from the runtime used to implement it. A ComputationClaim is always CANDIDATE and cannot authorize actuation. PlanningAdvice can reorder an externally supplied formal planner frontier but cannot add or remove members of that frontier.

Consequential mutation remains exclusively:

public semantic projection -> admission -> durable intent -> prepared receipt -> Ash.Reactor DO -> sealed receipt -> replay.

The new computation modules do not call Xaas.Actuation, manufacture authority evidence, or persist an Ash resource. If persistence is later required, it must be manufactured from the repository's canonical ontology/ggen path rather than by hand-writing a second semantic source.

This preserves the Blue River Dam boundary: model/runtime implementations are replaceable downstream computation; semantics, admission, authority, consequence, and receipts remain upstream control.
