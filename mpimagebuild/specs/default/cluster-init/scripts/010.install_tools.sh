#!/bin/bash

set -x
set -e


# Install the tools required for the build
apt clean
apt update
apt upgrade -y
apt install -y apt-utils vim wget gnupg2 unzip libncurses5 ca-certificates curl apt-transport-https lsb-release
apt install -y git jq

# Install Azure CLI
sudo apt-get update
sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
    sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get install -y azure-cli


# Install Packer
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install packer

# Required for podman (emulating Docker) builds
# USERNAME=packer
# useradd -m -s /bin/bash ${USERNAME}
# sudo -u ${USERNAME} usermod --add-subuids 100000-165535 --add-subgids 100000-165535 ${USERNAME}
# sudo -u ${USERNAME} podman system migrate

