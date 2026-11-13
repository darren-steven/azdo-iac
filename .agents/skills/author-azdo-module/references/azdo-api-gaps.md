# Azure DevOps Provider vs. REST API Coverage Reference

The `microsoft/azuredevops` OpenTofu/Terraform provider covers project-level resources well, but several **Organization-level Security & Pipeline Settings** are only accessible via the Azure DevOps REST API (`/_apis/settings/entries/host` or `/_apis/policy/configurations`).

## 1. Settings Handled Natively by `microsoft/azuredevops`

| Domain | Resource Name | Notes |
| :--- | :--- | :--- |
| **Projects** | `azuredevops_project`, `azuredevops_project_features` | Supports `visibility = "private"`, `version_control = "Git"`, `work_item_template`, and feature toggles (`boards`, `repositories`, `pipelines`, `testplans`, `artifacts`). |
| **Project Pipeline Settings** | `azuredevops_project_pipeline_settings` | Enforces job authorization scope (`enforce_job_scope`), limit variables settable at queue time (`enforce_settable_var`), publish pipeline metadata (`publish_pipeline_metadata`), and protect access to repos in YAML pipelines (`enforce_referenced_repo_scoped_token`). |
| **Git Repositories** | `azuredevops_git_repository` | Manages repo lifecycle, default branch (`refs/heads/main`), and initialization. |
| **Branch Policies** | `azuredevops_branch_policy_min_reviewers`, `azuredevops_branch_policy_build_validation`, `azuredevops_branch_policy_comment_resolution`, `azuredevops_branch_policy_work_item_linking`, `azuredevops_branch_policy_merge_types`, `azuredevops_branch_policy_auto_reviewers` | Full support for default branch protection and path-filtered required reviewers (`path_filters`). |
| **Identity & Groups** | `azuredevops_group`, `azuredevops_team`, `azuredevops_group_membership`, `azuredevops_user_entitlement` | Supports both org-scoped (`scope = null`) and project-scoped groups. |
| **Permissions** | `azuredevops_git_permissions`, `azuredevops_project_permissions`, `azuredevops_build_definition_permissions`, `azuredevops_security_permissions` | Native permission assignment per resource or namespace. |
| **Environments & Library** | `azuredevops_environment`, `azuredevops_variable_group`, `azuredevops_check_approval` | Variable groups support native Azure Key Vault integration via the `key_vault {}` block. |
| **Agent Pools** | `azuredevops_agent_pool`, `azuredevops_agent_queue` | Org-level pool definition and project-level queue authorization. |

---

## 2. Organization-Level Policies Requiring the REST API Bridge (`modules/org-settings-api-bridge`)

These settings live under the Azure DevOps Organization Settings hierarchy (`https://dev.azure.com/{org}/_apis/settings/entries/host?api-version=7.1-preview.1`) and are managed in `modules/org-settings-api-bridge`:

| Setting Key / Policy | Tier | Baseline Enforcement | REST Endpoint |
| :--- | :--- | :--- | :--- |
| **Allow Public Projects** (`Policy.AllowOrgPublicProjects`) | **Tier 1 (Locked `false`)** | Always disabled (`false`) so no project can ever be flipped to public. | `PATCH /_apis/settings/entries/host` |
| **Disallow Anonymous Access** (`Policy.DisallowAnonymousAccess`) | **Tier 1 (Locked `true`)** | Always enabled (`true`) to block unauthenticated access. | `PATCH /_apis/settings/entries/host` |
| **Disable Classic Build Pipelines** (`Pipelines.General.DisableClassicBuildPipelines`) | **Tier 1 (Locked `true`)** | Enforces YAML-only build pipelines across the org. | `PATCH /_apis/settings/entries/host` |
| **Disable Classic Release Pipelines** (`Pipelines.General.DisableClassicReleasePipelines`) | **Tier 1 (Locked `true`)** | Enforces YAML multi-stage deployments across the org. | `PATCH /_apis/settings/entries/host` |
| **Enforce Entra ID Conditional Access** (`Policy.EnforceAADConditionalAccess`) | **Tier 1 (Locked `true`)** | Enforces tenant Conditional Access policies on web and API flows. | `PATCH /_apis/settings/entries/host` |
| **Allow Team Admins to Invite Users** (`Policy.AllowTeamAdminsInvitations`) | **Tier 2 (Dial)** | Default `false`; configurable in `config/org.yaml` (`security_dials.allow_team_admins_invite`). | `PATCH /_apis/settings/entries/host` |
| **Enable SSH Authentication** (`Policy.EnableSshAuthentication`) | **Tier 2 (Dial)** | Default `true`; configurable in `config/org.yaml` (`security_dials.ssh_authentication_enabled`). | `PATCH /_apis/settings/entries/host` |
| **Disallow OAuth Third-Party App Access** (`Policy.DisallowOAuthAuthentication`) | **Tier 2 (Dial)** | Default `true` (disallow third-party OAuth); configurable in `config/org.yaml`. | `PATCH /_apis/settings/entries/host` |
