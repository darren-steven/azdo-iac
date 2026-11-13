variable "organization_name" {
  description = "Azure DevOps organization slug name."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{1,62}$", var.organization_name))
    error_message = "organization_name must be a valid Azure DevOps organization slug."
  }
}

variable "allow_team_admins_invite" {
  description = "Tier 2 Dial: Whether Project and Team Administrators are allowed to invite new users."
  type        = bool
  default     = false
}

variable "ssh_authentication_enabled" {
  description = "Tier 2 Dial: Whether SSH public key authentication is enabled for Git repositories."
  type        = bool
  default     = true
}

variable "disallow_third_party_oauth" {
  description = "Tier 2 Dial: Whether third-party OAuth application access is blocked across the organization."
  type        = bool
  default     = true
}

variable "enable_rest_bridge" {
  description = "Enable live REST API calls to the Azure DevOps Organization Settings endpoint (set false during offline plan testing without credentials)."
  type        = bool
  default     = true
}
