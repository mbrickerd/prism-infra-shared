terraform {
  backend "azurerm" {
    subscription_id      = "1e702451-e125-465b-ba86-4343891daaa8"
    resource_group_name  = "rg-prism-cluster-shared"
    storage_account_name = "saprismclustershared"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
