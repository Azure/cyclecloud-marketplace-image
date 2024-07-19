packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}


source "azure-arm" "cyclecloud_builder" {
  os_type = "Linux"
  ssh_pty = "true"
  disk_additional_size = [512]

  image_publisher = "${var.image_publisher}"
  image_offer = "${var.image_offer}"
  image_sku = "${var.image_sku}"

  subscription_id = "${var.subscription_id}"
  managed_image_name = "cc-${var.cyclecloud_version}-${var.image_name}-${formatdate("YYYYMMDDhhmm", timestamp())}"
  managed_image_resource_group_name = "${var.resource_group}"

  virtual_network_name = "${var.virtual_network_name}"
  virtual_network_subnet_name = "${var.virtual_network_subnet_name}"
  virtual_network_resource_group_name = "${var.virtual_network_resource_group_name}"

  azure_tags = {
    imagebuilder = "cyclecloud"
  }

  location = "${var.location}"
  vm_size = "${var.vm_size}"
}

build {

  sources = ["source.azure-arm.cyclecloud_builder"]
    
  provisioner "file" {
    source = "../scripts/setup_cyclecloud.sh"
    destination = "/tmp/setup_cyclecloud.sh"
  }

  provisioner "file" {
    source = "../scripts/do_generalize.sh"
    destination = "/tmp/do_generalize.sh"
  }

  provisioner "file" {
    source = "../scripts/install_cli.py"
    destination = "/tmp/install_cli.py"
  }


  provisioner "shell" {

    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    
    inline = [
        "set -e",
        "chmod +x /tmp/setup_cyclecloud.sh",
        "/tmp/setup_cyclecloud.sh ${var.cyclecloud_version}",
        "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]

    environment_vars = [
        "CYCLECLOUD_VERSION=${var.cyclecloud_version}"
    ]

    inline_shebang  = "/bin/sh -x"
    skip_clean      = true
  }


}


