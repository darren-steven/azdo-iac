variable "config_dir" {
  description = "Relative path to the declarative YAML configuration directory."
  type        = string
  default     = "../../config"
}

variable "enable_rest_bridge" {
  description = "Whether to enable live REST API calls for organization-level settings not in microsoft/azuredevops."
  type        = bool
  default     = false
}

variable "azdo_personal_access_token" {
  description = "Optional token used by the REST API bridge (prefer AZDO_PERSONAL_ACCESS_TOKEN env var or OIDC bearer token)."
  type        = string
  sensitive   = true
  default     = ""
}
