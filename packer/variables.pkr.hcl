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
  default = "8-gen2"
}

variable "vm_size" {
  type = string
  default = "Standard_E2ads_v5"
}

variable "cyclecloud_version" {
  type = string
}

variable "build_resource_group_name" {
  type = string
}

variable "virtual_network_name" {
  type = string
}

variable "virtual_network_subnet_name" {
  type = string
  default = "default"
}

variable "virtual_network_resource_group_name" {
  type = string
}

variable "user_assigned_identity_client_id" {
  type = string
}

variable "cyclecloud_package_name" {
  type = string
  default = ""  
}

variable "repo_stream"{
  type = string
  default = "prod"
}
