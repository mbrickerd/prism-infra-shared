module "app_registration" {
  source = "git::https://github.com/mbrickerd/terraform-azure-modules.git//modules/app-registration?ref=bf4876f9a6db8f130a27e3baa4b3c1c0400c305b"

  display_name = "mb-prism-sensor-clustering-${var.environment}"
}

resource "azuread_service_principal" "prism_terraform_shared" {
  client_id = module.app_registration.client_id
  tags      = ["terraform", var.environment, "prism-cluster"]
}

resource "github_actions_secret" "azure_client_id" {
  repository      = "prism-infra-shared"
  secret_name     = "AZURE_CLIENT_ID"
  plaintext_value = module.app_registration.client_id
}

resource "github_actions_secret" "azure_subscription_id" {
  repository      = "prism-infra-shared"
  secret_name     = "AZURE_SUBSCRIPTION_ID"
  plaintext_value = data.azurerm_client_config.current.subscription_id
}

resource "github_actions_secret" "azure_tenant_id" {
  repository      = "prism-infra-shared"
  secret_name     = "AZURE_TENANT_ID"
  plaintext_value = data.azurerm_client_config.current.tenant_id
}

resource "azuread_application_federated_identity_credential" "github_infra_shared_main" {
  application_id = module.app_registration.id
  display_name   = "github-infra-shared-main"
  description    = "GitHub Actions workflow identity for deployment from main branch of shared infrastructure repository."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:mbrickerd/prism-infra-shared:ref:refs/heads/main"
}

resource "azuread_application_federated_identity_credential" "github_infra_shared_pr" {
  application_id = module.app_registration.id
  display_name   = "github-infra-shared-pr"
  description    = "GitHub Actions workflow identity for validation of pull requests in shared infrastructure repository."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:mbrickerd/prism-infra-shared:pull_request"
}

module "resource_group" {
  source = "git::https://github.com/mbrickerd/terraform-azure-modules.git//modules/resource-group?ref=bf4876f9a6db8f130a27e3baa4b3c1c0400c305b"

  name        = var.name
  environment = var.environment
  location    = var.location

  tags = {
    managed_by_terraform = true
    purpose              = "shared-infrastructure"
    critical             = "true"
  }
}

resource "azurerm_role_assignment" "resource_group_contributor" {
  scope                = module.resource_group.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.prism_terraform_shared.id
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

  tags = {
    managed_by_terraform = true
    purpose              = "shared-infrastructure"
    critical             = "true"
  }
}

resource "github_actions_secret" "azure_storage_connection_string" {
  repository      = "prism-infra-shared"
  secret_name     = "AZURE_STORAGE_CONNECTION_STRING"
  plaintext_value = module.storage_account.primary_blob_connection_string
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = module.storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.prism_terraform_shared.id
}

module "tfstate_storage_container" {
  source = "git::https://github.com/mbrickerd/terraform-azure-modules.git//modules/storage-container?ref=bf4876f9a6db8f130a27e3baa4b3c1c0400c305b"

  name               = "shared-tfstate"
  storage_account_id = data.azurerm_storage_account.bootstrap.id
  metadata           = {}
}

resource "azurerm_role_assignment" "bootstrap_storage_access" {
  scope                = "${data.azurerm_storage_account.bootstrap.id}/blobServices/default/containers/tfstate"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.prism_terraform_shared.id
}

resource "azurerm_role_assignment" "bootstrap_storage_reader" {
  scope                = data.azurerm_storage_account.bootstrap.id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.prism_terraform_shared.id
}

module "data_storage_container" {
  source = "git::https://github.com/mbrickerd/terraform-azure-modules.git//modules/storage-container?ref=bf4876f9a6db8f130a27e3baa4b3c1c0400c305b"

  name               = "data"
  storage_account_id = module.storage_account.id
  metadata           = {}
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

  tags = {
    managed_by_terraform = true
    purpose              = "shared-infrastructure"
    critical             = "true"
  }
}
