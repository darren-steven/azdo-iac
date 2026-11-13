Analyzed main.tf:L1-105
Analyzed main.tf:L1-155
Analyzed branch_policies.tf:L1-128

Here is how the OpenTofu codebase works end-to-end—tracing the flow from the YAML configuration files in `config/` through the root orchestrator in `environments/prod-org` down to each of the 5 reusable modules in `modules/`.

---

## High-Level Data Flow

```
config/org.yaml ─────────┐
config/groups.yaml ──────┼──► environments/prod-org/main.tf (yamldecode)
config/projects/*.yaml ──┘              │
                                        ├──► 1. module "org_baseline" (modules/org-baseline)
                                        │         └──► 2. module "org_settings_bridge" (modules/org-settings-api-bridge)
                                        │
                                        └──► 3. module "projects" [for_each project] (modules/project-archetype)
                                                  └──► 4. module "security_constants" (modules/security-namespaces)
```

---

## 0. Root Orchestrator: `environments/prod-org`

The `environments/prod-org` folder is the **only place where `tofu init / plan / apply` is executed**. It contains zero raw `resource` blocks; its job is to decode YAML, merge defaults, and wire the modules together.

* **[versions.tf](environments/prod-org/versions.tf#L1-L24)**:
  * Pins OpenTofu `>= 1.8.0` and the `microsoft/azuredevops` and `Mastercard/restapi` providers, plus a ready-to-uncomment `azurerm` remote state backend block.
* **[variables.tf](environments/prod-org/variables.tf#L1-L19)**:
  * Defines runtime switches such as `config_dir` (pointing to `../../config`) and `enable_rest_bridge` (whether to execute raw REST calls against the organization settings API).
* **[main.tf](environments/prod-org/main.tf#L8-L95)**:
  1. **YAML Decoding ([lines 8–18](environments/prod-org/main.tf#L8-L18))**:
     * Reads `config/org.yaml` and `config/groups.yaml` using `yamldecode(file(...))`.
     * Uses `fileset("${var.config_dir}/projects", "*.yaml")` to automatically discover every project YAML file in `config/projects/` and builds a map keyed by `project.key` (`local.projects_by_key`). Dropping a new `.yaml` file into `config/projects/` automatically adds it to the OpenTofu graph without editing `.tf` files.
  2. **Provider Wiring ([lines 20–33](environments/prod-org/main.tf#L20-L33))**:
     * Configures `provider "azuredevops"` with `org_service_url` from `config/org.yaml`, relying on the short-lived Entra ID token exported as `AZDO_PERSONAL_ACCESS_TOKEN` by `scripts/tofu-local.sh`.
  3. **Organization Module Call ([lines 38–46](environments/prod-org/main.tf#L38-L46))**:
     * Calls `module "org_baseline"` once for the organization.
  4. **Project Module Fan-Out & Dial Inheritance ([lines 51–95](environments/prod-org/main.tf#L51-L95))**:
     * Calls `module "projects"` with `for_each = local.projects_by_key`.
     * Uses `try(each.value.branch_policy_dials.<dial>, local.org_config.repository_defaults.<dial>)` ([lines 64–89](environments/prod-org/main.tf#L64-L89)) so every project inherits the organization's default branch policies from `config/org.yaml` unless it explicitly overrides a dial within allowed bounds.

---

## 1. Module: `modules/org-baseline`

Manages organization-level identity groups, agent pools, and invokes the REST API bridge.

* **[variables.tf](modules/org-baseline/variables.tf#L1-L49)**:
  * Validates that every group in `config/groups.yaml` has a valid `role_tier` (`platform-admin`, `maintainer`, `auditor`, or `service-principal-automation`).
* **[main.tf](modules/org-baseline/main.tf#L1-L52)**:
  * **Indexing ([lines 7–10](modules/org-baseline/main.tf#L7-L10))**: Converts the YAML lists of groups and agent pools into `for_each` maps keyed by `name`. This ensures removing or reordering a group in YAML only touches that specific group in Azure DevOps.
  * **`azuredevops_group.org_groups` ([lines 22–28](modules/org-baseline/main.tf#L22-L28))**: Creates organization-scoped security groups (or links to an Entra ID Group if `entra_group_origin_id` is supplied) and prefixes descriptions with `[ROLE-TIER]`.
  * **`azuredevops_agent_pool.pools` ([lines 30–37](modules/org-baseline/main.tf#L30-L37))**: Creates organization-level agent pools (`contoso-linux-mdp`, `contoso-regulated-mdp`) with `auto_provision = false` so pools aren't automatically exposed to every project without explicit authorization.

---

## 2. Module: `modules/org-settings-api-bridge`

Isolates the gap where `microsoft/azuredevops` lacks native resources for Organization-level Security & Pipeline switches.

* **[main.tf](modules/org-settings-api-bridge/main.tf#L11-L51)**:
  * **`local.enforced_org_settings` ([lines 12–28](modules/org-settings-api-bridge/main.tf#L12-L28))**: Combines two sets of keys into one payload:
    1. **Tier 1 Hardcoded Baselines ([lines 16–20](modules/org-settings-api-bridge/main.tf#L16-L20))**: `Policy.AllowOrgPublicProjects = false`, `Policy.DisallowAnonymousAccess = true`, `Policy.EnforceAADConditionalAccess = true`, and `DisableClassicBuild/ReleasePipelines = true`. Because these have no input variables in [variables.tf](modules/org-settings-api-bridge/variables.tf), no YAML change can ever weaken them.
    2. **Tier 2 Dials ([lines 25–27](modules/org-settings-api-bridge/main.tf#L25-L27))**: `AllowTeamAdminsInvitations`, `EnableSshAuthentication`, and `DisallowOAuthAuthentication` passed down from `config/org.yaml`.
  * **`restapi_object.org_host_settings` ([lines 31–46](modules/org-settings-api-bridge/main.tf#L31-L46))**: Guarded by `count = var.enable_rest_bridge ? 1 : 0`, targeting `/_apis/settings/entries/host`.

---

## 3. Module: `modules/security-namespaces`

A pure data/constants module (no API calls) that translates human-readable team roles (`reader`, `contributor`, `lead`) into Azure DevOps permission maps.

* **[main.tf](modules/security-namespaces/main.tf#L9-L64)**:
  * **`local.namespace_ids` ([lines 10–17](modules/security-namespaces/main.tf#L10-L17))**: Documents the well-known GUIDs for Project, Git Repositories, Build, Release, Library, and Analytics security namespaces.
  * **`local.git_role_permissions` ([lines 20–53](modules/security-namespaces/main.tf#L20-L53))**: Defines the exact permission dictionary for `reader`, `contributor`, and `lead`. Notice that across **all three** roles, `ForcePush = "deny"`, `EditPolicies = "deny"`, `DeleteRepository = "deny"`, and `ManagePermissions = "deny"` are hardcoded so even project leads cannot bypass branch policies or rewrite `main` history.

---

## 4. Module: `modules/project-archetype`

The heavy lifter that provisions an entire governed Azure DevOps project. It is split across four files for readability:

### A. Input Validation: [variables.tf](modules/project-archetype/variables.tf#L1-L165)
* Enforces HCL-level `validation {}` blocks as the final line of defense (even if someone bypassed the JSON Schema):
  * `min_reviewers >= 2 && min_reviewers <= 5` ([lines 80–83](modules/project-archetype/variables.tf#L80-L83))
  * `build_validation_expiry_hours >= 12 && build_validation_expiry_hours <= 72` ([lines 85–88](modules/project-archetype/variables.tf#L85-L88))
  * At least one merge strategy enabled ([lines 90–98](modules/project-archetype/variables.tf#L90-L98))

### B. Core Project, Teams, Repos, Environments & Variables: [main.tf](modules/project-archetype/main.tf#L1-L154)
* **Archetype Floor Calculation ([lines 15–25](modules/project-archetype/main.tf#L15-L25))**:
  * If a project sets `archetype = "regulated-workload"`, `local.effective_min_reviewers` automatically enforces `max(3, var.branch_policy_dials.min_reviewers)`.
* **Cross-Product Flattening ([lines 28–37](modules/project-archetype/main.tf#L28-L37))**:
  * Computes `local.team_repo_permissions` by pairing every team in the project with every repository (`"Team Name::Repo Name"`), so each team gets its role's permissions applied to each repository.
* **Project & Pipeline Settings ([lines 43–68](modules/project-archetype/main.tf#L43-L68))**:
  * `azuredevops_project.this` hardcodes `visibility = "private"` and `version_control = "Git"`, and wires the 5 feature toggles (`boards`, `repositories`, `pipelines`, `testplans`, `artifacts`).
  * `azuredevops_project_pipeline_settings.this` locks down job authorization tokens and sets `status_badges_are_private = true`.
* **Teams, Repos & Permissions ([lines 73–102](modules/project-archetype/main.tf#L73-L102))**:
  * Creates `azuredevops_team.teams`, `azuredevops_git_repository.repos` (initialized with `init_type = "Clean"` so `refs/heads/main` exists immediately), and applies `azuredevops_git_permissions.team_repo_access` using `module.security_constants.git_role_permissions[each.value.role]`.
* **Environments & Approval Checks ([lines 107–132](modules/project-archetype/main.tf#L107-L132))**:
  * Creates `azuredevops_environment.envs` (`dev`, `staging`, `prod`).
  * For any environment where `require_approval = true`, creates `azuredevops_check_approval.env_approvals` pointing to `azuredevops_team.teams[each.value.approver_team].id` with `requester_can_approve = false`.
* **Variable Groups ([lines 137–154](modules/project-archetype/main.tf#L137-L154))**:
  * Creates `azuredevops_variable_group.plain_vars` with `allow_access = false` (requiring explicit per-pipeline authorization).

### C. Default Branch Protection Policies: [branch_policies.tf](modules/project-archetype/branch_policies.tf#L1-L128)
Attaches 5 separate policy resources to every repository's default branch (`refs/heads/main`):
1. **`azuredevops_branch_policy_min_reviewers` ([lines 24–44](modules/project-archetype/branch_policies.tf#L24-L44))**: Hardcodes `enabled = true`, `blocking = true`, `submitter_can_vote = false`, and `last_pusher_cannot_approve = true`, while using the dial values for `reviewer_count` and `on_push_reset_approved_votes`.
2. **`azuredevops_branch_policy_comment_resolution` ([lines 47–64](modules/project-archetype/branch_policies.tf#L47-L64))**: Requires all PR comment threads to be resolved.
3. **`azuredevops_branch_policy_work_item_linking` ([lines 67–84](modules/project-archetype/branch_policies.tf#L67-L84))**: Requires linked Azure Boards work items on PRs.
4. **`azuredevops_branch_policy_merge_types` ([lines 87–106](modules/project-archetype/branch_policies.tf#L87-L106))**: Enforces allowed merge strategies (`allow_squash`, `allow_basic_no_fast_forward`, `allow_rebase_and_fast_forward`, `allow_rebase_with_merge`).
5. **`azuredevops_branch_policy_auto_reviewers` ([lines 109–128](modules/project-archetype/branch_policies.tf#L109-L128))**: Flattens each repo's `path_reviewers` list and creates path-filtered mandatory reviewer rules (e.g., `/infra/*` and `/.azdo/*` requiring `Example Service Maintainers`).

---

## 5. Module: `modules/self-governance-policies`

* **[main.tf](modules/self-governance-policies/main.tf#L12-L63)**:
  * Standalone optional module. While this repo is hosted in GitHub, [.github/CODEOWNERS](.github/CODEOWNERS) enforces that only Platform Admins can approve changes to `/modules/*`, `/schemas/*`, `/policies/*`, and `/.agents/*`. If you ever move or mirror this repo into Azure Repos, instantiating `self-governance-policies` creates the exact same path-filter rules using `azuredevops_branch_policy_auto_reviewers`.