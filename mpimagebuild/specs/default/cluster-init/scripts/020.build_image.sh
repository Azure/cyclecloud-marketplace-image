#!/bin/bash
set -x
set -e

BUILD_DIR=/opt/cycle/cyclecloud-marketplace-image

pushd /opt/cycle
git clone https://github.com/Azure/cyclecloud-marketplace-image.git
cd cyclecloud-marketplace-image



# ./build.sh -p azure -v 1.0.0 -s default -c ccmarketplace.pkr.hcl -d

# packer init .
# packer build -var-file=variables.pkr.hcl ./ccmarketplace.pkr.hcl
