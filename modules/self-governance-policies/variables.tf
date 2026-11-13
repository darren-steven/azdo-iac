variable "project_id" {
  description = "Azure DevOps Project ID hosting the AzDo-IaC repository (if mirrored/hosted in Azure Repos)."
  type        = string
}

variable "repository_id" {
  description = "Azure DevOps Git Repository ID for the AzDo-IaC repository."
  type        = string
}

variable "default_branch" {
  description = "Default branch ref to protect."
  type        = string
  default     = "refs/heads/main"
}

variable "platform_admins_group_id" {
  description = "Group/Team ID for AzDO Platform Admins (required for Engine, Schema, Policy, and AI Skill changes)."
  type        = string
}

variable "maintainers_group_id" {
  description = "Group/Team ID for AzDO Governance Maintainers (required for config/projects/* and config/groups.yaml changes)."
  type        = string
}
