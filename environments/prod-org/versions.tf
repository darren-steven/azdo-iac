terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">= 1.3.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 1.19.0"
    }
  }

  # Uncomment and configure your Azure Blob Storage backend when bootstrapping state:
  # backend "azurerm" {
  #   resource_group_name  = "rg-azdo-iac-state"
  #   storage_account_name = "stazdoiacstate"
  #   container_name       = "tfstate"
  #   key                  = "prod-org.tfstate"
  #   use_oidc             = true
  # }
}
