# =============================================================================
# Module: self-governance-policies
# =============================================================================
# Portable equivalent to `.github/CODEOWNERS` for Azure Repos.
# If this repository is hosted in GitHub (recommended for out-of-band bootstrap
# and recovery), `.github/CODEOWNERS` enforces path-scoped reviews natively.
# If this repository is hosted or mirrored in Azure Repos, instantiate this
# module to enforce the exact same path-based approval boundary via
# `azuredevops_branch_policy_auto_reviewers`.
# =============================================================================

resource "azuredevops_branch_policy_auto_reviewers" "platform_engine_guardrail" {
  project_id = var.project_id
  enabled    = true
  blocking   = true

  settings {
    auto_reviewer_ids  = [var.platform_admins_group_id]
    submitter_can_vote = false
    message            = "Platform Admin approval is required for changes to the OpenTofu Engine, Schemas, Policies, AI Skills, or Org-wide Dials."
    path_filters = [
      "/modules/*",
      "/environments/*",
      "/schemas/*",
      "/policies/*",
      "/scripts/*",
      "/.agents/*",
      "/.github/*",
      "/AGENTS.md",
      "/GEMINI.md",
      "/config/org.yaml"
    ]

    scope {
      repository_id  = var.repository_id
      repository_ref = var.default_branch
      match_type     = "Exact"
    }
  }
}

resource "azuredevops_branch_policy_auto_reviewers" "maintainer_dials_review" {
  project_id = var.project_id
  enabled    = true
  blocking   = true

  settings {
    auto_reviewer_ids          = [var.maintainers_group_id, var.platform_admins_group_id]
    submitter_can_vote         = false
    minimum_number_of_reviewers = 1
    message                    = "Governance Maintainer or Platform Admin approval is required for project onboarding and group dial changes."
    path_filters = [
      "/config/projects/*",
      "/config/groups.yaml"
    ]

    scope {
      repository_id  = var.repository_id
      repository_ref = var.default_branch
      match_type     = "Exact"
    }
  }
}
