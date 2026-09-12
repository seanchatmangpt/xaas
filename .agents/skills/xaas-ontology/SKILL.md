---
name: xaas-ontology
description: Workflow for managing RDF ontology, ggen code generation, and Ash domain resource generation in XAAS.
---

# XAAS Ontology & ggen Workflow

Guidelines and workflow steps for maintaining `ontology.ttl` and running ggen synchronization to generate Ash resources and domain models.

---

## Workflow

### 1. RDF Model Definition
- Edit `/Users/sac/xaas/ontology.ttl` to declare entities, relationships, attributes, and SHACL constraints.
- Maintain semantic consistency with RDF namespaces and Ash schema expectations.

### 2. Code Generation (`ggen`)
- Run code generator:
  ```bash
  ggen sync
  ```
- Or run custom generation scripts if configured:
  ```bash
  ./scripts/gen_ash_resources.sh
  ```

### 3. Verify Generated Ash Artifacts
- Check generated Ash resource files under `lib/xaas/`.
- Verify compilation:
  ```bash
  mix compile
  ```
- Generate and apply any needed database migrations:
  ```bash
  mix ash.codegen
  mix ash.migrate
  ```

### 4. Verification & Testing
- Run domain unit tests to verify generated resource behaviors:
  ```bash
  mix test test/xaas/
  ```
