variable "name" {
  description = "The base name that will be used in the resource group naming convention."
  type        = string
}

variable "environment" {
  description = "Specifies the environment the resource group belongs to."
  type        = string
  default     = "shared"

  validation {
    condition     = contains(["shared", "common"], var.environment)
    error_message = "Invalid value for environment. Must be one of: `shared`, `common`."
  }
}

variable "location" {
  description = "The Azure Region where the Resource Group should exist. Defaults to `westeurope`."
  type        = string
  default     = "westeurope"
}
