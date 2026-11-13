# =============================================================================
# Module: project-archetype (Core Project, Teams, Permissions & Environments)
# =============================================================================

module "security_constants" {
  source = "../security-namespaces"
}

locals {
  teams_by_name        = { for t in var.teams : t.name => t }
  repos_by_name        = { for r in var.repositories : r.name => r }
  environments_by_name = { for e in var.environments : e.name => e }
  var_groups_by_name   = { for vg in var.variable_groups : vg.name => vg }

  # Enforce regulated-workload archetype floor (>= 3 reviewers, <= 12h expiry)
  effective_min_reviewers = (
    var.archetype == "regulated-workload"
    ? max(3, var.branch_policy_dials.min_reviewers)
    : var.branch_policy_dials.min_reviewers
  )
  effective_build_expiry_minutes = (
    var.archetype == "regulated-workload"
    ? min(12, var.branch_policy_dials.build_validation_expiry_hours) * 60
    : var.branch_policy_dials.build_validation_expiry_hours * 60
  )

  # Flatten team x repository permission pairs
  team_repo_permissions = merge([
    for team_name, team in local.teams_by_name : {
      for repo_name, repo in local.repos_by_name :
      "${team_name}::${repo_name}" => {
        team_name = team_name
        repo_name = repo_name
        role      = team.role
      }
    }
  ]...)
}

# -----------------------------------------------------------------------------
# 1. Project & Pipeline Security Settings (Tier 1 Private Visibility Hardcoded)
# -----------------------------------------------------------------------------
resource "azuredevops_project" "this" {
  name               = var.project_name
  description        = "[Archetype: ${var.archetype}] ${var.description}"
  visibility         = "private" # TIER 1 IMMUTABLE BASELINE: Always private
  version_control    = "Git"     # TIER 1 IMMUTABLE BASELINE: Always Git
  work_item_template = var.process_template

  features = {
    boards       = var.features.boards
    repositories = var.features.repositories
    pipelines    = var.features.pipelines
    testplans    = var.features.testplans
    artifacts    = var.features.artifacts
  }
}

resource "azuredevops_project_pipeline_settings" "this" {
  project_id = azuredevops_project.this.id

  enforce_job_scope                    = var.pipeline_dials.enforce_job_auth_scope_to_project
  enforce_job_scope_for_release        = true # TIER 1 IMMUTABLE BASELINE
  enforce_referenced_repo_scoped_token = var.pipeline_dials.enforce_referenced_repo_scoped_token
  enforce_settable_var                 = var.pipeline_dials.enforce_settable_var_at_queue
  publish_pipeline_metadata            = var.pipeline_dials.publish_pipeline_metadata
  status_badges_are_private            = true # TIER 1 IMMUTABLE BASELINE: Never expose public badges
}

# -----------------------------------------------------------------------------
# 2. Teams & Least-Privilege Repository Permissions
# -----------------------------------------------------------------------------
resource "azuredevops_team" "teams" {
  for_each = local.teams_by_name

  project_id  = azuredevops_project.this.id
  name        = each.value.name
  description = each.value.description
}

resource "azuredevops_git_repository" "repos" {
  for_each = local.repos_by_name

  project_id     = azuredevops_project.this.id
  name           = each.value.name
  default_branch = each.value.default_branch

  initialization {
    init_type = "Clean"
  }
}

resource "azuredevops_git_permissions" "team_repo_access" {
  for_each = local.team_repo_permissions

  project_id    = azuredevops_project.this.id
  repository_id = azuredevops_git_repository.repos[each.value.repo_name].id
  principal     = azuredevops_team.teams[each.value.team_name].descriptor
  replace       = false

  permissions = module.security_constants.git_role_permissions[each.value.role]
}

# -----------------------------------------------------------------------------
# 3. Environments & Production Approval Gates
# -----------------------------------------------------------------------------
resource "azuredevops_environment" "envs" {
  for_each = local.environments_by_name

  project_id  = azuredevops_project.this.id
  name        = each.value.name
  description = each.value.description
}

resource "azuredevops_check_approval" "env_approvals" {
  for_each = {
    for k, env in local.environments_by_name : k => env
    if env.require_approval && env.approver_team != null
  }

  project_id           = azuredevops_project.this.id
  target_resource_id   = azuredevops_environment.envs[each.key].id
  target_resource_type = "environment"

  requester_can_approve = false # TIER 1 IMMUTABLE BASELINE: No self-approval on deployments
  minimum_required_approvers = 1
  timeout               = 43200

  approvers = [
    azuredevops_team.teams[each.value.approver_team].descriptor
  ]
}

# -----------------------------------------------------------------------------
# 4. Non-Secret Variable Groups (Secret groups require Key Vault linkage)
# -----------------------------------------------------------------------------
resource "azuredevops_variable_group" "plain_vars" {
  for_each = {
    for k, vg in local.var_groups_by_name : k => vg
    if vg.key_vault == null && length(vg.variables) > 0
  }

  project_id   = azuredevops_project.this.id
  name         = each.value.name
  description  = each.value.description
  allow_access = false # TIER 1 IMMUTABLE BASELINE: Must explicitly authorize per pipeline

  dynamic "variable" {
    for_each = each.value.variables
    content {
      name      = variable.key
      value     = variable.value
      is_secret = false
    }
  }
}
