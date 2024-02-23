variable "location" {
  type = string
  default = "eastus"
}

variable "resource_group" {
  type = string
  default = "azure-cyclecloud-packer-rg"
}

variable "subscription_id" {
  type = string
}

variable "image_name" {
  type = string
  default = "alma8"
}

variable "image_publisher" {
  type = string
  default = "almalinux"
}

variable "image_offer" {
  type = string
  default = "almalinux-x86_64"
}

variable "image_sku" {
  type = string
  default = "8_7-gen2"
}

variable "vm_size" {
  type = string
  default = "Standard_D2s_v5"
}

variable "cyclecloud_version" {
  type = string
}

