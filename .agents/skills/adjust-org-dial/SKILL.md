---
name: adjust-org-dial
description: >-
  Guides maintainers through safely inspecting and modifying an exposed organization,
  group, or project configuration dial in config/*.yaml within approved baseline bounds.
  Use this skill when a user asks to change an Azure DevOps policy, branch setting,
  pipeline timeout, reviewer count, or project setting.
---

# Adjust Organization or Project Dial (`adjust-org-dial`)

Use this skill whenever a user wants to modify an existing setting for the Azure DevOps Organization (`config/org.yaml`), organization groups (`config/groups.yaml`), or a project (`config/projects/<project>.yaml`).

## Workflow Steps

### Step 1: Identify Target Scope & Classify the Request
1. Determine whether the user wants to adjust:
   - **Organization-wide setting** -> [config/org.yaml](../../../config/org.yaml) (Schema: [schemas/org.schema.json](../../../schemas/org.schema.json))
   - **Organization group / entitlement** -> [config/groups.yaml](../../../config/groups.yaml) (Schema: [schemas/groups.schema.json](../../../schemas/groups.schema.json))
   - **Project-specific setting** -> `config/projects/<project-key>.yaml` (Schema: [schemas/project.schema.json](../../../schemas/project.schema.json))
2. Check [docs/dials-catalog.md](../../../docs/dials-catalog.md) and the corresponding JSON Schema in `schemas/` to verify whether the requested setting is:
   - **Tier 2 (Exposed Bounded Dial)**: Check the allowed `minimum`, `maximum`, or `enum` values.
   - **Tier 1 (Locked Baseline)**: Not exposed in YAML or locked by `policies/*.rego` (e.g., making a project public, allowing 1 reviewer on default branch, allowing self-approval, enabling classic pipelines).

### Step 2: Enforce Baseline Guardrail (If Out of Bounds)
- **STOP** if the requested value violates a Tier 1 baseline or falls outside Tier 2 schema bounds.
- **Do NOT** edit `modules/`, `schemas/`, or `policies/` to force the change through.
- Explain clearly to the user:
  1. Why the requested value is blocked by the organization baseline.
  2. The allowed bounds for that dial (e.g., `min_reviewers` allows `2` to `5`).
  3. Ask if they would like to apply the nearest compliant value instead.

### Step 3: Apply the Change in `config/`
- Edit only the relevant YAML file in `config/`.
- Preserve the `# yaml-language-server: $schema=...` directive at the top of the file and keep existing comments intact.

### Step 4: Validate & Report Blast Radius
1. Run the validation suite:
   ```bash
   ./scripts/validate.sh
   ```
2. Summarize the change for the user, explicitly stating:
   - **Modified Dial & Value**: Old value -> New value.
   - **Blast Radius**: Single repository, single project, or all projects across the organization.
   - **Approval Required**: `Maintainer` approval (for `config/projects/*` and `config/groups.yaml`) or `Platform Admin` approval (for `config/org.yaml`).
