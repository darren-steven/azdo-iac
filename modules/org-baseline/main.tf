# =============================================================================
# Module: org-baseline
# =============================================================================
# Enforces organization-level settings, security groups, and agent pools.
# =============================================================================

locals {
  groups_by_name = { for g in var.organization_groups : g.name => g }
  pools_by_name  = { for p in var.agent_pools : p.name => p }
}

module "org_settings_bridge" {
  source = "../org-settings-api-bridge"

  organization_name          = var.organization_name
  allow_team_admins_invite   = var.security_dials.allow_team_admins_invite
  ssh_authentication_enabled = var.security_dials.ssh_authentication_enabled
  disallow_third_party_oauth = var.security_dials.disallow_third_party_oauth
  enable_rest_bridge         = var.enable_rest_bridge
}

resource "azuredevops_group" "org_groups" {
  for_each = local.groups_by_name

  display_name = each.value.entra_group_origin_id == null ? each.value.name : null
  description  = each.value.entra_group_origin_id == null ? "[${upper(each.value.role_tier)}] ${each.value.description}" : null
  origin_id    = each.value.entra_group_origin_id
}

resource "azuredevops_agent_pool" "pools" {
  for_each = local.pools_by_name

  name           = each.value.name
  pool_type      = each.value.pool_type
  auto_provision = each.value.auto_provision
  auto_update    = each.value.auto_update
}

output "organization_group_descriptors" {
  description = "Map of organization group display names to their AzDO descriptors."
  value       = { for k, v in azuredevops_group.org_groups : k => v.descriptor }
}

output "agent_pool_ids" {
  description = "Map of organization agent pool names to their IDs."
  value       = { for k, v in azuredevops_agent_pool.pools : k => v.id }
}

output "effective_org_settings" {
  description = "Summary of enforced Tier 1 and Tier 2 organization settings."
  value       = module.org_settings_bridge.effective_org_settings
}
