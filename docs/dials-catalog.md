# Azure DevOps Organization Baseline & Dials Catalog

This catalog documents every governance control managed by `AzDo-IaC`, classified into:

- **Tier 1 — Immutable Baselines**: Locked in the OpenTofu engine (`modules/`) and OPA policies (`policies/`). Cannot be overridden via YAML configuration.
- **Tier 2 — Bounded Dials**: Exposed in `config/*.yaml` and constrained by JSON Schemas (`schemas/*.schema.json`) and OpenTofu `validation {}` blocks.

---

## 1. Tier 1: Immutable Baselines (Locked in Code)

| Domain | Control / Invariant | Enforced Value | Enforcing Module / Policy | Security Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **Organization Security** | `Policy.AllowOrgPublicProjects` | `false` | `modules/org-settings-api-bridge` | Prevents accidental public exposure of source code, work items, or pipelines. |
| **Organization Security** | `Policy.DisallowAnonymousAccess` | `true` | `modules/org-settings-api-bridge` | Blocks unauthenticated read access across all organization endpoints. |
| **Organization Security** | `Policy.EnforceAADConditionalAccess` | `true` | `modules/org-settings-api-bridge` | Enforces Entra ID Conditional Access policies (MFA, compliant device, IP bounds) on web and REST/Git flows. |
| **Pipelines** | `DisableClassicBuildPipelines` & `DisableClassicReleasePipelines` | `true` | `modules/org-settings-api-bridge` | Mandates version-controlled, PR-reviewed YAML pipelines; blocks click-ops pipeline definitions. |
| **Pipelines** | `status_badges_are_private` | `true` | `modules/project-archetype` | Requires authentication to view pipeline status badges. |
| **Projects** | `visibility` & `version_control` | `"private"`, `"Git"` | `modules/project-archetype` | Every project is private and uses Git (TFVC disabled). |
| **Branch Protection** | `submitter_can_vote` & `last_pusher_cannot_approve` | `false`, `true` | `modules/project-archetype/branch_policies.tf` | Enforces true four-eyes review; PR authors and the most recent pusher cannot approve their own changes. |
| **Branch Protection** | `ForcePush` & `EditPolicies` permissions | `"deny"` | `modules/security-namespaces` | Denies force-push and manual branch policy edits even for Project Leads; branch policies are managed solely by IaC. |
| **Deployments** | Production Environment Approval (`prod` / `production`) | `require_approval = true`, `requester_can_approve = false` | `policies/project_guardrails.rego` & `modules/project-archetype` | Requires independent approval from a designated lead team before production deployment. |
| **Secrets Management** | Plain-text secrets in `variable_groups` | Blocked (`PROJ-POLICY-007`) | `policies/project_guardrails.rego` | Prevents credentials, tokens, or connection strings from being committed to Git; mandates Azure Key Vault linkage. |

---

## 2. Tier 2: Exposed Organization Dials (`config/org.yaml`)

> **Approval Requirement**: Changes to `config/org.yaml` affect the entire organization and require `@org/azdo-platform-admins` review.

| YAML Path | Type | Default | Allowed Bounds | Description & Blast Radius |
| :--- | :--- | :--- | :--- | :--- |
| `organization.default_process_template` | `string` | `"Agile"` | `"Agile"`, `"Scrum"`, `"CMMI"`, `"Basic"` | Default work item process template for newly onboarded projects. |
| `security_dials.allow_team_admins_invite` | `boolean` | `false` | `true` / `false` | Whether Project and Team Admins can invite new users into the AzDO organization. |
| `security_dials.ssh_authentication_enabled` | `boolean` | `true` | `true` / `false` | Whether Git over SSH is enabled across the organization. |
| `security_dials.disallow_third_party_oauth` | `boolean` | `true` | `true` / `false` | Blocks legacy third-party OAuth app access (Entra ID OIDC remains enabled). |
| `pipeline_dials.default_job_timeout_minutes` | `integer` | `60` | `15` .. `180` | Default pipeline job timeout in minutes. |
| `pipeline_dials.enforce_settable_var_at_queue` | `boolean` | `true` | `true` / `false` | Restricts queue-time variables to those explicitly marked settable in the pipeline definition. |
| `pipeline_dials.enforce_job_auth_scope_to_project` | `boolean` | `true` | `true` / `false` | Scopes build job authorization tokens to the current project rather than the whole collection. |
| `pipeline_dials.enforce_referenced_repo_scoped_token` | `boolean` | `true` | `true` / `false` | Restricts YAML pipeline tokens to repositories explicitly listed in `resources.repositories`. |
| `repository_defaults.min_reviewers` | `integer` | `2` | `2` .. `5` | Organization-wide default minimum reviewers on default branch PRs. |
| `repository_defaults.reset_votes_on_new_push` | `boolean` | `true` | `true` / `false` | Resets reviewer approvals when new commits are pushed to a PR. |
| `repository_defaults.require_work_item_linking` | `boolean` | `true` | `true` / `false` | Requires every PR to link at least one work item. |
| `repository_defaults.require_comment_resolution` | `boolean` | `true` | `true` / `false` | Requires all PR review threads to be resolved before merge. |
| `repository_defaults.build_validation_expiry_hours` | `integer` | `24` | `12` .. `72` | Hours before a PR build validation expires when the target branch changes. |
| `repository_defaults.allowed_merge_types.*` | `object` | `squash: true`, `no_fast_forward: true` | At least 1 `true` | Controls which merge strategies (`squash`, `no_fast_forward`, `rebase`, `rebase_merge`) are permitted. |

---

## 3. Tier 2 & Tier 3: Project Archetypes & Dials (`config/projects/<key>.yaml`)

> **Approval Requirement**: Changes to `config/projects/*.yaml` are scoped to a single project and can be approved by `@org/azdo-maintainers`.

| Archetype | `min_reviewers` Bound | `build_validation_expiry_hours` Bound | Intended Use Case |
| :--- | :--- | :--- | :--- |
| `standard-microservice` | `2` .. `5` (Default: `2`) | `12` .. `72` (Default: `24`) | Standard engineering services, libraries, and internal applications. |
| `regulated-workload` | **`3` .. `5`** (Enforced >= 3) | **`12`** (Enforced <= 12) | PCI/SOX/regulated services requiring stricter quorum and fresher build validation. |
| `sandbox` | `2` .. `5` (Default: `2`) | `12` .. `72` (Default: `48`) | Non-production proofs of concept isolated from production service connections. |
