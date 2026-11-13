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
}
