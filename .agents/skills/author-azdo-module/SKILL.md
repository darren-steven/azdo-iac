---
name: author-azdo-module
description: >-
  Enforces OpenTofu coding standards for Azure DevOps modules, including when to use
  the microsoft/azuredevops provider versus the REST API bridge and how to manage
  security namespace permission bitmasks. Use this skill when writing or refactoring
  HCL code in modules/ or environments/.
---

# Author Azure DevOps OpenTofu Modules (`author-azdo-module`)

Use this skill whenever writing, reviewing, or refactoring OpenTofu (`.tf`) files in `modules/` or `environments/`.

## Core HCL Engineering Standards

### 1. Native Resource vs. REST API Bridge Decision
Before writing a resource, check [azdo-api-gaps.md](./references/azdo-api-gaps.md) to confirm whether the Azure DevOps setting is supported natively by `microsoft/azuredevops` or requires `modules/org-settings-api-bridge`:
- **Supported Natively (`microsoft/azuredevops`)**: Projects, project features, Git repositories, branch policies (`min_reviewers`, `build_validation`, `work_item_linking`, `comment_resolution`, `merge_types`, `auto_reviewers`), teams, groups, group memberships, user entitlements, agent pools, environments, variable groups, service endpoints, and security permissions.
- **Requires REST API Bridge (`modules/org-settings-api-bridge`)**: Organization-level security policies (`Policy.DisallowAnonymousAccess`, `Policy.AllowOrgPublicProjects`, `Policy.AllowTeamAdminsInvitations`, `Policy.EnforceAADConditionalAccess`), SSH authentication policy, and organization-level pipeline settings (`Pipelines.DisableClassicBuildPipelines`, `Pipelines.DisableClassicReleasePipelines`).

### 2. Collection Indexing (`for_each` over `count`)
- **Always use `for_each`** with stable string keys (e.g., `for_each = { for repo in var.repositories : repo.name => repo }`).
- **Never use `count`** for lists of projects, repositories, teams, or environments. Reordering a list in YAML when `count` is used will cause OpenTofu to destroy and recreate Azure DevOps resources.
- Use `count = var.enabled ? 1 : 0` **only** for singleton conditional resources.

### 3. Security Namespace Permission Bitmasks
- Never scatter raw hexadecimal or integer bitmasks across modules without named constants.
- Use [modules/security-namespaces](../../../modules/security-namespaces/main.tf) which maps human-readable permission names (`GenericRead`, `PullRequestContribute`, `ForcePush`, `EditBuildQuality`, `AdministerBuildPermissions`) to Azure DevOps security namespace GUIDs and bit tokens.

### 4. Protecting Tier 1 Invariants in HCL
- In `modules/project-archetype/`, always hardcode:
  - `visibility = "private"` on `azuredevops_project`
  - `enabled = true` and `blocking = true` on baseline branch policy resources (`min_reviewers`, `merge_types`, `comment_resolution`)
  - `submitter_can_vote = false` and `last_pusher_cannot_approve = true` on `azuredevops_branch_policy_min_reviewers`

### 5. Validation Step
Always run `./scripts/validate.sh` after creating or modifying `.tf` files.
