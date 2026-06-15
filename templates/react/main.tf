terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "personaldevtfstate"
    container_name       = "tfstate"
    key                  = "{{APP_NAME}}.tfstate"
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  description = "Azure region for the Static Web App"
  type        = string
  default     = "canadacentral"
}

variable "app_name" {
  description = "Name of the Static Web App"
  type        = string
  default     = "{{APP_NAME}}"
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.app_name}"
  location = var.location
}

resource "azurerm_static_web_app" "main" {
  name                = var.app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_tier            = "Free"
  sku_size            = "Free"
}

output "static_web_app_url" {
  value = azurerm_static_web_app.main.default_host_name
}

output "static_web_app_api_key" {
  value     = azurerm_static_web_app.main.api_key
  sensitive = true
}
