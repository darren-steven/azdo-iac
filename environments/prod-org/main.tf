# =============================================================================
# Root Entrypoint: environments/prod-org
# =============================================================================
# Decodes the declarative YAML dials in `config/` and invokes the protected
# OpenTofu baseline modules.
# =============================================================================

locals {
  org_config    = yamldecode(file("${var.config_dir}/org.yaml"))
  groups_config = yamldecode(file("${var.config_dir}/groups.yaml"))

  project_files = fileset("${var.config_dir}/projects", "*.yaml")
  projects_by_key = {
    for f in local.project_files :
    yamldecode(file("${var.config_dir}/projects/${f}")).project.key =>
    yamldecode(file("${var.config_dir}/projects/${f}")).project
  }
}

provider "azuredevops" {
  org_service_url = local.org_config.organization.service_url
  # Authentication is supplied via environment variables:
  # - AZDO_PERSONAL_ACCESS_TOKEN or Entra ID OIDC Workload Identity Federation
}

provider "restapi" {
  uri                  = local.org_config.organization.service_url
  write_returns_object = true

  headers = {
    "Content-Type" = "application/json"
  }
}

# -----------------------------------------------------------------------------
# 1. Organization Baseline & Security Dials
# -----------------------------------------------------------------------------
module "org_baseline" {
  source = "../../modules/org-baseline"

  organization_name   = local.org_config.organization.name
  security_dials      = local.org_config.security_dials
  organization_groups = local.groups_config.organization_groups
  agent_pools         = local.org_config.agent_pools
  enable_rest_bridge  = var.enable_rest_bridge
}

# -----------------------------------------------------------------------------
# 2. Project Archetypes & Per-Project Dials
# -----------------------------------------------------------------------------
module "projects" {
  source   = "../../modules/project-archetype"
  for_each = local.projects_by_key

  org_service_url           = local.org_config.organization.service_url
  project_key               = each.value.key
  project_name              = each.value.name
  description               = each.value.description
  archetype                 = each.value.archetype
  process_template          = try(each.value.process_template, local.org_config.organization.default_process_template)
  create_default_repository = try(each.value.create_default_repository, false)
  features                  = each.value.features
  pipeline_dials            = local.org_config.pipeline_dials

  # Merge org-level repository_defaults with any project-specific dial overrides
  branch_policy_dials = {
    min_reviewers = try(
      each.value.branch_policy_dials.min_reviewers,
      local.org_config.repository_defaults.min_reviewers
    )
    reset_votes_on_new_push = try(
      each.value.branch_policy_dials.reset_votes_on_new_push,
      local.org_config.repository_defaults.reset_votes_on_new_push
    )
    require_work_item_linking = try(
      each.value.branch_policy_dials.require_work_item_linking,
      local.org_config.repository_defaults.require_work_item_linking
    )
    require_comment_resolution = try(
      each.value.branch_policy_dials.require_comment_resolution,
      local.org_config.repository_defaults.require_comment_resolution
    )
    build_validation_expiry_hours = try(
      each.value.branch_policy_dials.build_validation_expiry_hours,
      local.org_config.repository_defaults.build_validation_expiry_hours
    )
    allowed_merge_types = try(
      each.value.branch_policy_dials.allowed_merge_types,
      local.org_config.repository_defaults.allowed_merge_types
    )
  }

  teams           = each.value.teams
  repositories    = each.value.repositories
  environments    = try(each.value.environments, [])
  variable_groups = try(each.value.variable_groups, [])
}

output "enforced_org_settings" {
  description = "Effective Tier 1 + Tier 2 organization settings."
  value       = module.org_baseline.effective_org_settings
}

output "provisioned_project_ids" {
  description = "Map of project keys to Azure DevOps project GUIDs."
  value       = { for k, p in module.projects : k => p.project_id }
}
