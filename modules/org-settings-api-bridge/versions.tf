terraform {
  required_version = ">= 1.8.0"

  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 1.19.0"
    }
  }
}
