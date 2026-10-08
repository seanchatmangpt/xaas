# v26.9.21 — ZOE private meeting inference provider

## Gap closed

The ZOE event simulator already manufactures candidate operational obligations and XaaS already carries Nx/Bumblebee/EXLA dependencies. The current `ash_a2a` v26.9.21 source owns UNKNOWN budgeting, candidate-only LLM standing, admission, CommandBus, and authority refusal. XaaS at this exact base still locks `ash_a2a` v26.9.12, so this change does **not** claim those newer APIs are wired into the XaaS runtime. The missing local seam closed here is narrower: a ZOE-specific **private local provider adapter** that converts a transcript into the typed observation envelope consumed by the project gym without using a frontier inference API.

`Xaas.Zoe.PrivateMeetingInference` closes that source seam:

```text
transcript
  -> local {:local, model_dir} Bumblebee model only
  -> Nx.Serving
  -> minimal typed requirement observations
  -> authority=OBSERVE_CONSTRUCT_ONLY
  -> do_authority=false
  -> Church Gym semantic delta
  -> sJira candidates
  -> existing AshA2A admission/BRCE (separate)
```

## Fences

- remote/Hugging Face repository identifiers are not accepted by this adapter;
- a local model directory is required;
- `.model-manifest.sha256` is required, must cover every regular file in the local model tree, and every listed artifact is recomputed before loading; symlinks and unbound files fail closed; the manifest digest is the model identity;
- model output may classify only independently sealed ideal requirement ids;
- raw generated notes/quotes are discarded from the result; model-created novelty is constrained to a closed enum so arbitrary names/PII cannot escape through a `kind` field;
- returned evidence references are derived from the local transcript digest rather than trusted from model output;
- no action, provider mutation, CommandBus dispatch, Planning Center write, or standing promotion exists in this module.

## Existing prior art reused

- `Bumblebee` + `Nx` + `EXLA` are already direct XaaS dependencies.
- `ash_a2a` v26.9.21 provides `AshA2A.Semantic.Unknown.route/3` for bounded UNKNOWN resolution and `AshA2A.Semantic.LlmBoundary` for candidate-only model output.
- XaaS `Xaas.Actuation.run/4` remains the only consequential DO route.
- XaaS's locked `ash_a2a` v26.9.12 is deliberately not hand-edited here. Consuming v26.9.21 requires a released dependency resolution and regenerated `mix.lock` through Mix; until then, the provider output is only a typed handoff envelope.

No competing LLM admission or execution framework is introduced, and no newer `ash_a2a` runtime standing is inherited by this branch.

## Evidence ceiling

Source and pure decoder/refusal courts can be verified without model weights. An actual private inference claim additionally requires an admitted local model directory, a verified `.model-manifest.sha256`, successful Bumblebee/Nx execution, and the resulting receipt. Until that run exists, the provider runtime itself remains `UNKNOWN`/`UNSUPPORTED(environment)` rather than `ALIVE`.
