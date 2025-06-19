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
apt-get update
apt-get install ca-certificates curl apt-transport-https lsb-release gnupg
mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    tee /etc/apt/keyrings/microsoft.gpg > /dev/null
 chmod go+r /etc/apt/keyrings/microsoft.gpg
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list
apt update && apt-get install -y azure-cli


# Install Packer
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt update && apt install packer

# Required for podman (emulating Docker) builds
# USERNAME=packer
# useradd -m -s /bin/bash ${USERNAME}
# sudo -u ${USERNAME} usermod --add-subuids 100000-165535 --add-subgids 100000-165535 ${USERNAME}
# sudo -u ${USERNAME} podman system migrate

