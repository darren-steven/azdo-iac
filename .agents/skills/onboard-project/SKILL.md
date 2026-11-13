---
name: onboard-project
description: >-
  Walks maintainers through onboarding a new Azure DevOps project, configuring its
  governance archetype, teams, repositories, environments, and Key Vault-linked
  variable groups via config/projects/<project-key>.yaml. Use this skill when a user
  asks to create or onboard a new project, team, or repository.
---

# Onboard an Azure DevOps Project (`onboard-project`)

Use this skill when a maintainer wants to create a new Azure DevOps project or add repositories, teams, or environments to an existing project in `config/projects/`.

## Workflow Steps

### Step 1: Gather Required Project Parameters
If the user has not specified them, ask for or confirm:
1. **Project Name & Key**: Slug-friendly filename (`config/projects/<project-key>.yaml`) and display name.
2. **Governance Archetype**:
   - `standard-microservice` (Default: min 2 reviewers, squash/no-fast-forward merge, 24h build expiry, standard environments `dev`, `staging`, `prod`).
   - `regulated-workload` (High security: min 3 reviewers, mandatory work item linking, mandatory comment resolution, 12h build expiry, approval gates on `staging` and `prod`).
   - `sandbox` (Experimentation: min 2 reviewers on `main`, relaxed branch creation, isolated to non-production agent pools and service connections).
3. **Repositories & Default Teams**: List of Git repositories and project teams to provision.

### Step 2: Scaffold from Approved Template
- Reference the example template at [standard-microservice.yaml](./examples/standard-microservice.yaml) and schema at [project.schema.json](../../../schemas/project.schema.json).
- Create `config/projects/<project-key>.yaml` with `# yaml-language-server: $schema=../../schemas/project.schema.json` on line 1.
- Ensure any secret variable groups specify a `key_vault` block (never store raw secret values in YAML).

### Step 3: Run Pre-Flight Validation
1. Execute the repository validation harness:
   ```bash
   ./scripts/validate.sh
   ```
2. Confirm that JSON Schema validation, OPA/Conftest policy checks, and OpenTofu validation succeed with zero errors.

### Step 4: Summarize Provisioned Resources
Provide a clear summary of what OpenTofu will create when the PR is merged:
- Project visibility (`private` enforced by baseline) and enabled features (`boards`, `repositories`, `pipelines`, `testplans`, `artifacts`).
- Teams and permission mappings.
- Repositories and branch policies applied to `refs/heads/main`.
- Environments and variable groups.
