variable "project_key" {
  description = "Unique immutable slug key for the project."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,48}$", var.project_key))
    error_message = "project_key must be 3-49 lowercase alphanumeric characters or hyphens."
  }
}

variable "project_name" {
  description = "Display name of the Azure DevOps project."
  type        = string
}

variable "description" {
  description = "Project description."
  type        = string
}

variable "archetype" {
  description = "Governance archetype for the project."
  type        = string
  default     = "standard-microservice"

  validation {
    condition     = contains(["standard-microservice", "regulated-workload", "sandbox"], var.archetype)
    error_message = "archetype must be one of: standard-microservice, regulated-workload, sandbox."
  }
}

variable "process_template" {
  description = "Work item process template."
  type        = string
  default     = "Agile"

  validation {
    condition     = contains(["Agile", "Scrum", "CMMI", "Basic"], var.process_template)
    error_message = "process_template must be one of: Agile, Scrum, CMMI, Basic."
  }
}

variable "features" {
  description = "Project feature toggles."
  type = object({
    boards       = string
    repositories = string
    pipelines    = string
    testplans    = string
    artifacts    = string
  })
}

variable "pipeline_dials" {
  description = "Pipeline governance dials inherited from org.yaml."
  type = object({
    enforce_settable_var_at_queue        = bool
    enforce_job_auth_scope_to_project    = bool
    enforce_referenced_repo_scoped_token = bool
    publish_pipeline_metadata            = bool
  })
}

variable "branch_policy_dials" {
  description = "Tier 2 bounded branch policy dials for default branches."
  type = object({
    min_reviewers                 = number
    reset_votes_on_new_push       = bool
    require_work_item_linking     = bool
    require_comment_resolution    = bool
    build_validation_expiry_hours = number
    allowed_merge_types = object({
      squash          = bool
      no_fast_forward = bool
      rebase          = bool
      rebase_merge    = bool
    })
  })

  validation {
    condition     = var.branch_policy_dials.min_reviewers >= 2 && var.branch_policy_dials.min_reviewers <= 5
    error_message = "[Tier 2 Bound] branch_policy_dials.min_reviewers must be between 2 and 5."
  }

  validation {
    condition     = var.branch_policy_dials.build_validation_expiry_hours >= 12 && var.branch_policy_dials.build_validation_expiry_hours <= 72
    error_message = "[Tier 2 Bound] branch_policy_dials.build_validation_expiry_hours must be between 12 and 72 hours."
  }

  validation {
    condition = (
      var.branch_policy_dials.allowed_merge_types.squash ||
      var.branch_policy_dials.allowed_merge_types.no_fast_forward ||
      var.branch_policy_dials.allowed_merge_types.rebase ||
      var.branch_policy_dials.allowed_merge_types.rebase_merge
    )
    error_message = "At least one merge strategy must be enabled in allowed_merge_types."
  }
}

variable "teams" {
  description = "Project teams and role mappings."
  type = list(object({
    name        = string
    description = string
    role        = string
    members     = optional(list(string), [])
  }))

  validation {
    condition     = alltrue([for t in var.teams : contains(["reader", "contributor", "lead"], t.role)])
    error_message = "Every team role must be one of: reader, contributor, lead."
  }
}

variable "repositories" {
  description = "Git repositories to manage in the project."
  type = list(object({
    name                           = string
    default_branch                 = optional(string, "refs/heads/main")
    build_validation_pipeline_name = optional(string)
    path_reviewers = optional(list(object({
      team_name = string
      paths     = list(string)
      blocking  = optional(bool, true)
    })), [])
  }))
}

variable "environments" {
  description = "Pipeline deployment environments."
  type = list(object({
    name             = string
    description      = string
    require_approval = bool
    approver_team    = optional(string)
  }))
  default = []
}

variable "variable_groups" {
  description = "Project variable groups (plain-text non-secrets or Key Vault linked secrets)."
  type = list(object({
    name        = string
    description = string
    variables   = optional(map(string), {})
    key_vault = optional(object({
      name                    = string
      service_connection_name = string
      secret_names            = list(string)
    }))
  }))
  default = []
}
