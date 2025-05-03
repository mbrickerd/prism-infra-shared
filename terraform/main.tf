module "app_registration" {
  source = "git::https://github.com/mbrickerd/terraform-azure-modules.git//modules/app-registration?ref=bf4876f9a6db8f130a27e3baa4b3c1c0400c305b"

  display_name = "mb-prism-sensor-clustering"
}

resource "azuread_service_principal" "prism_terraform_shared" {
  client_id = module.app_registration.client_id
  tags      = ["terraform", "shared", "prism-cluster"]
}

resource "azuread_application_federated_identity_credential" "github_infra_shared_main" {
  application_id = module.app_registration.id
  display_name   = "github-infra-shared-main"
  description    = "Federated identity for GitHub Actions in shared environment resources"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:mbrickerd/prism-infra-shared:ref:refs/heads/main"
}

resource "azuread_application_federated_identity_credential" "github_infra_shared_pr" {
  application_id = module.app_registration.id
  display_name   = "github-infra-shared-pr"
  description    = "Federated identity for GitHub Actions in shared environment resources"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:mbrickerd/prism-infra-shared:pull_request"
}

resource "azurerm_role_assignment" "subscription_contributor" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.prism_terraform_shared.id
}

module "resource_group" {
  source = "git::https://github.com/mbrickerd/terraform-azure-modules.git//modules/resource-group?ref=bf4876f9a6db8f130a27e3baa4b3c1c0400c305b"

  name        = var.name
  environment = var.environment
  location    = var.location
}

module "storage_account" {
  source = "git::https://github.com/mbrickerd/terraform-azure-modules.git//modules/storage-account?ref=bf4876f9a6db8f130a27e3baa4b3c1c0400c305b"

  resource_group_name           = module.resource_group.name
  name                          = var.name
  environment                   = var.environment
  location                      = var.location
  public_network_access_enabled = true
  shared_access_key_enabled     = true
  allowed_copy_scope            = "AAD"
  network_rules = {
    default_action             = "Allow"
    bypass                     = ["AzureServices"]
    ip_rules                   = []
    virtual_network_subnet_ids = []
    private_link_access        = []
  }
}

module "storage_container" {
  source = "git::https://github.com/mbrickerd/terraform-azure-modules.git//modules/storage-container?ref=bf4876f9a6db8f130a27e3baa4b3c1c0400c305b"

  name               = "tfstate"
  storage_account_id = module.storage_account.id
  metadata           = {}
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = module.storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.prism_terraform_shared.id
}

module "container_registry" {
  source = "git::https://github.com/mbrickerd/terraform-azure-modules.git//modules/container-registry?ref=bf4876f9a6db8f130a27e3baa4b3c1c0400c305b"

  resource_group_name           = module.resource_group.name
  name                          = replace(var.name, "-", "")
  environment                   = var.environment
  location                      = var.location
  sku                           = "Basic"
  public_network_access_enabled = true
  quarantine_policy_enabled     = false
  zone_redundancy_enabled       = false
  data_endpoint_enabled         = false
  georeplications               = []
  network_rule_set              = null
}
