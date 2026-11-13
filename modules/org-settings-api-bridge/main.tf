# =============================================================================
# Module: org-settings-api-bridge
# =============================================================================
# Bridges the gap for Azure DevOps Organization-level security & pipeline
# settings that are not yet exposed as native resources in `microsoft/azuredevops`.
#
# Tier 1 Immutable Baselines are HARDCODED in `local.enforced_org_settings`
# so they cannot be weakened via variables or YAML dials.
# =============================================================================

locals {
  enforced_org_settings = {
    # -------------------------------------------------------------------------
    # TIER 1 IMMUTABLE BASELINES (Hardcoded — Never expose as variables)
    # -------------------------------------------------------------------------
    "Policy.AllowOrgPublicProjects"                    = false
    "Policy.DisallowAnonymousAccess"                   = true
    "Policy.EnforceAADConditionalAccess"               = true
    "Pipelines.General.DisableClassicBuildPipelines"   = true
    "Pipelines.General.DisableClassicReleasePipelines" = true

    # -------------------------------------------------------------------------
    # TIER 2 BOUNDED DIALS (Driven from validated config/org.yaml)
    # -------------------------------------------------------------------------
    "Policy.AllowTeamAdminsInvitations"  = var.allow_team_admins_invite
    "Policy.EnableSshAuthentication"     = var.ssh_authentication_enabled
    "Policy.DisallowOAuthAuthentication" = var.disallow_third_party_oauth
  }
}

resource "restapi_object" "org_host_settings" {
  count = var.enable_rest_bridge ? 1 : 0

  path         = "/_apis/settings/entries/host?api-version=7.1-preview.1"
  read_path    = "/_apis/settings/entries/host?api-version=7.1-preview.1"
  update_path  = "/_apis/settings/entries/host?api-version=7.1-preview.1"
  destroy_path = "/_apis/settings/entries/host?api-version=7.1-preview.1"

  id_attribute = "id"
  object_id    = var.organization_name

  data = jsonencode(merge(
    { id = var.organization_name },
    local.enforced_org_settings
  ))
}

output "effective_org_settings" {
  description = "Complete map of Tier 1 locked and Tier 2 dial organization settings."
  value       = local.enforced_org_settings
}
