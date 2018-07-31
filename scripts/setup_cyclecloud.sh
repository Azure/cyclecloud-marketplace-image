#!/bin/bash
set -ex
yum install -y java-1.8.0-openjdk-headless 
_tmpdir=$(mktemp -d)
pushd $_tmpdir

CS_ROOT=/opt/cycle_server

# Download the installer and install
if curl --output /dev/null --silent --head --fail "$CYCLECLOUD_INSTALLER_URL"; then
    echo "Downloading CycleCloud installer from $CYCLECLOUD_INSTALLER_URL"
    curl -f -L -S -o cylecloud-linux64.tar.gz "$CYCLECLOUD_INSTALLER_URL"
    tar -xf cylecloud-linux64.tar.gz
    ./cycle_server/install.sh --installdir $CS_ROOT --nostart
else
  echo "Installer URL invalid does not exist: $CYCLECLOUD_INSTALLER_URL"
  exit 1
fi

# Update properties
sed -i 's/webServerMaxHeapSize\=2048M/webServerMaxHeapSize\=4096M/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerPort\=8080/webServerPort\=80/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerSslPort\=8443/webServerSslPort\=443/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerEnableHttps\=false/webServerEnableHttps=true/' $CS_ROOT/config/cycle_server.properties

# Clenaup install dir
popd
rm -rf $_tmpdir
