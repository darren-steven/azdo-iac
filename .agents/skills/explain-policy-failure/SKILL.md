---
name: explain-policy-failure
description: >-
  Runs the validation suite (./scripts/validate.sh), parses JSON Schema, OPA/Conftest,
  or OpenTofu validation errors, explains in plain English why the guardrail blocked
  the change, and offers compliant remediation options. Use this skill when validation
  fails or when a maintainer asks why their change was rejected.
---

# Explain & Remediate Policy or Validation Failures (`explain-policy-failure`)

Use this skill whenever `./scripts/validate.sh` or a CI pipeline fails, or when a maintainer is unsure why an edit to `config/` or `modules/` was rejected.

## Workflow Steps

### Step 1: Execute Validation & Capture Output
Run the unified validation script:
```bash
./scripts/validate.sh
```

### Step 2: Classify the Failure Source
Identify which guardrail layer caught the issue:
1. **Layer 1 — JSON Schema Validation (`schemas/*.schema.json`)**:
   - Triggered by syntax errors, unknown YAML keys, wrong data types, or out-of-range numbers (`minimum` / `maximum` / `enum`).
2. **Layer 2 — Policy-as-Code Gate (`policies/*.rego`)**:
   - Triggered when a configuration violates an organization baseline invariant (e.g., regulated workload with fewer than 3 reviewers, inline secrets in a variable group without Key Vault linkage, or production environment missing required approval).
3. **Layer 3 — OpenTofu Validation (`modules/*/variables.tf`)**:
   - Triggered by HCL syntax issues or module `validation {}` blocks.

### Step 3: Translate into Plain Language for the Maintainer
Format your explanation clearly:
1. **What Failed**: File path and YAML field/line number.
2. **Why It Was Blocked**: The specific security or governance reason behind the guardrail (reference [docs/dials-catalog.md](../../../docs/dials-catalog.md)).
3. **How to Fix It Safely**: Provide the exact compliant YAML snippet within allowed Tier 2 bounds.
   - *Reminder*: Never suggest editing `schemas/`, `policies/`, or `modules/` to silence a validation error on a routine `config/` change.
