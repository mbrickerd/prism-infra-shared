terraform {
  backend "azurerm" {
    subscription_id      = "1e702451-e125-465b-ba86-4343891daaa8"
    resource_group_name  = "rg-prism-cluster-mgmt"
    storage_account_name = "saprismclustermgmt"
    container_name       = "shared-tfstate"
    key                  = "terraform.tfstate"
  }
}
