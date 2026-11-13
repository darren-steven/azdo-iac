variable "organization_name" {
  description = "Azure DevOps organization slug."
  type        = string
}

variable "security_dials" {
  description = "Tier 2 organization security dials from config/org.yaml."
  type = object({
    allow_team_admins_invite   = bool
    ssh_authentication_enabled = bool
    disallow_third_party_oauth = bool
  })
}

variable "organization_groups" {
  description = "Organization-level security groups from config/groups.yaml."
  type = list(object({
    name                  = string
    description           = string
    role_tier             = string
    entra_group_origin_id = optional(string)
    members               = optional(list(string), [])
  }))

  validation {
    condition = alltrue([
      for g in var.organization_groups :
      contains(["platform-admin", "maintainer", "auditor", "service-principal-automation"], g.role_tier)
    ])
    error_message = "Every organization group role_tier must be one of: platform-admin, maintainer, auditor, service-principal-automation."
  }
}

variable "agent_pools" {
  description = "Organization-level agent pools from config/org.yaml."
  type = list(object({
    name           = string
    pool_type      = optional(string, "automation")
    auto_provision = bool
    auto_update    = bool
  }))
  default = []
}

variable "enable_rest_bridge" {
  description = "Whether to invoke the REST API bridge for organization host settings."
  type        = bool
  default     = true
}
