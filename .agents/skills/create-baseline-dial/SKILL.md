---
name: create-baseline-dial
description: >-
  Guides Platform Engineers through exposing a new Tier 2 bounded configuration dial
  across OpenTofu modules, JSON Schemas, OPA Rego policies, YAML configs, and the
  dials catalog. Use this skill when a Platform Engineer asks to expose a new configurable
  dial or modify the baseline engine.
---

# Create or Evolve a Baseline Dial (`create-baseline-dial`)

Use this skill when a **Platform Engineer** wants to expose a new Tier 2 configuration dial or promote/demote a setting between Tier 1 (Immutable Baseline) and Tier 2 (Bounded Dial).

## Pre-Check: Confirm Platform Engineering Intent
Before modifying `modules/`, `schemas/`, or `policies/`, verify that the user is intentionally modifying the **Platform Baseline Engine** (and not just trying to work around a validation error on a single project).

## Four-Layer Lockstep Workflow

Every Tier 2 dial must be defined across four layers simultaneously so IDE validation, Policy-as-Code, OpenTofu execution, and documentation never drift:

### Step 1: Update JSON Schema (`schemas/*.schema.json`)
1. Add the property to [org.schema.json](../../../schemas/org.schema.json) or [project.schema.json](../../../schemas/project.schema.json).
2. Always include:
   - `type` (`integer`, `boolean`, `string`, `object`)
   - `description` (including the allowed bounds and default value)
   - Explicit bounds (`minimum` / `maximum`, `enum`, or `pattern`)
   - `default` value matching the OpenTofu variable default

### Step 2: Update OPA / Conftest Policy (`policies/*.rego`)
1. Add or update a `deny contains msg if { ... }` rule in [org_baseline.rego](../../../policies/org_baseline.rego) or [project_guardrails.rego](../../../policies/project_guardrails.rego).
2. Ensure the error message states:
   - Which field failed validation
   - The invalid value provided
   - The allowed range/values and the security rationale

### Step 3: Update OpenTofu Module & Root Wiring (`modules/` & `environments/`)
1. Add the input variable to the target module's `variables.tf` (e.g., `modules/org-baseline/variables.tf` or `modules/project-archetype/variables.tf`) with a `validation {}` block mirroring the schema bounds.
2. Wire the variable into the resource in `main.tf`.
3. Pass the decoded YAML value (with `try(..., default_value)`) from `environments/prod-org/main.tf` into the module call.

### Step 4: Update Documentation & Default Config (`docs/` & `config/`)
1. Document the new dial, its default, its allowed bounds, and its blast radius in [docs/dials-catalog.md](../../../docs/dials-catalog.md).
2. Add the dial with comments to `config/org.yaml` or `config/projects/example-service.yaml`.

### Step 5: Execute Full Validation Suite
```bash
./scripts/validate.sh
```
Ensure all schema, Rego policy, and OpenTofu validation checks pass.
