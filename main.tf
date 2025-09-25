terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  type    = string
  default = "East US"
}

variable "rg_name" {
  type    = string
  default = "rg-devops-mini-task"
}

variable "app_name" {
  type    = string
  default = "devops-mini-task-app"
}

resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_app_service_plan" "asp" {
  name                = "${var.app_name}-asp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Basic"
    size = "B1"
  }
}

resource "azurerm_application_insights" "ai" {
  name                = "${var.app_name}-ai"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

resource "azurerm_user_assigned_identity" "uai" {
  name                = "${var.app_name}-identity"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_key_vault" "kv" {
  name                        = "${var.app_name}-kv"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  soft_delete_enabled         = true
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    # This gives the tf user full access to manage secrets
    key_permissions = ["get","list","create","delete","update","set"]
    secret_permissions = ["get","list","set","delete"]
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_access_policy" "app_identity" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.uai.principal_id

  secret_permissions = [
    "get",
    "list"
  ]
}

resource "azurerm_key_vault_secret" "sample" {
  name         = "SAMPLE_SECRET"
  value        = "my-production-secret-value"
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_linux_web_app" "app" {
  name                = var.app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_app_service_plan.asp.id

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uai.id]
  }

  site_config {
    linux_fx_version = "PYTHON|3.9"
    # Configure Application Insights
    app_settings = {
      "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.ai.connection_string
      "SAMPLE_SECRET" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.sample.id})"
    }
  }

  tags = {
    environment = "production"
  }
}

resource "azurerm_linux_web_app_slot" "staging" {
  name                = "staging"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  site_config {
    linux_fx_version = "PYTHON|3.9"
    app_settings = {
      "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.ai.connection_string
      "SAMPLE_SECRET" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.sample.id})"
    }
  }
  app_service_plan_id = azurerm_app_service_plan.asp.id
  app_service_name    = azurerm_linux_web_app.app.name
}

output "app_default_hostname" {
  value = azurerm_linux_web_app.app.default_site_hostname
}
