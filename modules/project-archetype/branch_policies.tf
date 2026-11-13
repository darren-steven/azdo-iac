# =============================================================================
# Module: project-archetype (Branch Policies on Default Branches)
# =============================================================================
# Enforces Tier 1 Immutable Baselines (blocking = true, submitter_can_vote = false,
# last_pusher_cannot_approve = true) alongside Tier 2 Bounded Dials.
# =============================================================================

locals {
  # Flatten path-based auto-reviewers across repositories
  repo_path_reviewers = merge([
    for repo_name, repo in local.repos_by_name : {
      for idx, pr in coalesce(repo.path_reviewers, []) :
      "${repo_name}::${pr.team_name}::${idx}" => {
        repo_name = repo_name
        team_name = pr.team_name
        paths     = pr.paths
        blocking  = pr.blocking
      }
    }
  ]...)
}

# 1. Minimum Reviewers Policy (Tier 1 Locked + Tier 2 Dial)
resource "azuredevops_branch_policy_min_reviewers" "default_branch" {
  for_each = local.repos_by_name

  project_id = azuredevops_project.this.id
  enabled    = true # TIER 1 IMMUTABLE BASELINE
  blocking   = true # TIER 1 IMMUTABLE BASELINE

  settings {
    reviewer_count                         = local.effective_min_reviewers
    submitter_can_vote                     = false # TIER 1 IMMUTABLE BASELINE: No self-approval
    last_pusher_cannot_approve             = true  # TIER 1 IMMUTABLE BASELINE
    allow_completion_with_rejects_or_waits = false # TIER 1 IMMUTABLE BASELINE
    on_push_reset_approved_votes           = var.branch_policy_dials.reset_votes_on_new_push

    scope {
      repository_id  = azuredevops_git_repository.repos[each.key].id
      repository_ref = each.value.default_branch
      match_type     = "Exact"
    }
  }
}

# 2. Comment Resolution Policy
resource "azuredevops_branch_policy_comment_resolution" "default_branch" {
  for_each = {
    for k, r in local.repos_by_name : k => r
    if var.branch_policy_dials.require_comment_resolution
  }

  project_id = azuredevops_project.this.id
  enabled    = true
  blocking   = true # TIER 1 IMMUTABLE BASELINE

  settings {
    scope {
      repository_id  = azuredevops_git_repository.repos[each.key].id
      repository_ref = each.value.default_branch
      match_type     = "Exact"
    }
  }
}

# 3. Work Item Linking Policy
resource "azuredevops_branch_policy_work_item_linking" "default_branch" {
  for_each = {
    for k, r in local.repos_by_name : k => r
    if var.branch_policy_dials.require_work_item_linking
  }

  project_id = azuredevops_project.this.id
  enabled    = true
  blocking   = true # TIER 1 IMMUTABLE BASELINE

  settings {
    scope {
      repository_id  = azuredevops_git_repository.repos[each.key].id
      repository_ref = each.value.default_branch
      match_type     = "Exact"
    }
  }
}

# 4. Allowed Merge Strategies Policy
resource "azuredevops_branch_policy_merge_types" "default_branch" {
  for_each = local.repos_by_name

  project_id = azuredevops_project.this.id
  enabled    = true # TIER 1 IMMUTABLE BASELINE
  blocking   = true # TIER 1 IMMUTABLE BASELINE

  settings {
    allow_squash                  = var.branch_policy_dials.allowed_merge_types.squash
    allow_basic_no_fast_forward   = var.branch_policy_dials.allowed_merge_types.no_fast_forward
    allow_rebase_and_fast_forward = var.branch_policy_dials.allowed_merge_types.rebase
    allow_rebase_with_merge       = var.branch_policy_dials.allowed_merge_types.rebase_merge

    scope {
      repository_id  = azuredevops_git_repository.repos[each.key].id
      repository_ref = each.value.default_branch
      match_type     = "Exact"
    }
  }
}

# 5. Path-Scoped Automatic Reviewers (AzDO Native Equivalent to CODEOWNERS)
resource "azuredevops_branch_policy_auto_reviewers" "path_scoped" {
  for_each = local.repo_path_reviewers

  project_id = azuredevops_project.this.id
  enabled    = true
  blocking   = each.value.blocking

  settings {
    auto_reviewer_ids  = [azuredevops_team.teams[each.value.team_name].id]
    submitter_can_vote = false # TIER 1 IMMUTABLE BASELINE
    message            = "Mandatory path-scoped review required by ${each.value.team_name}"
    path_filters       = each.value.paths

    scope {
      repository_id  = azuredevops_git_repository.repos[each.value.repo_name].id
      repository_ref = local.repos_by_name[each.value.repo_name].default_branch
      match_type     = "Exact"
    }
  }
}
