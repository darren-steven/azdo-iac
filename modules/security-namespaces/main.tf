# =============================================================================
# Module: security-namespaces
# =============================================================================
# Provides named constants for Azure DevOps Security Namespace GUIDs and
# role-tier permission presets (`reader`, `contributor`, `lead`) so platform
# engineers never have to write raw hexadecimal bitmasks.
# =============================================================================

locals {
  namespace_ids = {
    project          = "52d39943-cb85-4d7f-8fa8-c6baac873819"
    git_repositories = "2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87"
    build            = "33344d9c-fc72-4d6f-aba5-fa317101a7e9"
    release          = "c788c23e-1b46-4162-8f5e-d7585343b5de"
    library          = "b7e84409-6553-448a-bbb2-af228e07cbeb"
    analytics        = "58450c49-b02d-465a-ab12-59ae512d6531"
  }

  # Standard Git Repository Permission Presets by Team Role
  git_role_permissions = {
    reader = {
      GenericRead           = "allow"
      GenericContribute     = "notset"
      CreateBranch          = "notset"
      PullRequestContribute = "notset"
      ForcePush             = "deny"
      EditPolicies          = "deny"
      DeleteRepository      = "deny"
      ManagePermissions     = "deny"
    }
    contributor = {
      GenericRead           = "allow"
      GenericContribute     = "allow"
      CreateBranch          = "allow"
      PullRequestContribute = "allow"
      ForcePush             = "deny" # Tier 1 Baseline: ForcePush denied by default
      EditPolicies          = "deny" # Tier 1 Baseline: Contributors cannot edit branch policies
      DeleteRepository      = "deny"
      ManagePermissions     = "deny"
    }
    lead = {
      GenericRead           = "allow"
      GenericContribute     = "allow"
      CreateBranch          = "allow"
      CreateTag             = "allow"
      PullRequestContribute = "allow"
      ManageNote            = "allow"
      ForcePush             = "deny" # Tier 1 Baseline: Even leads cannot force-push protected branches
      EditPolicies          = "deny" # Tier 1 Baseline: Branch policies are managed exclusively by IaC
      DeleteRepository      = "deny"
      ManagePermissions     = "deny"
    }
  }
}

output "namespace_ids" {
  description = "Well-known Azure DevOps Security Namespace GUIDs."
  value       = local.namespace_ids
}

output "git_role_permissions" {
  description = "Standardized least-privilege Git repository permission matrix per team role."
  value       = local.git_role_permissions
}
