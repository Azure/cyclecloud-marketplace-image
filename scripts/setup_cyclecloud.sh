#!/bin/bash
set -ex
yum -y update --security
yum install -y java-1.8.0-openjdk-headless 

# mount data disk
parted /dev/disk/azure/scsi1/lun0 --script -- mklabel gpt
parted -a optimal /dev/disk/azure/scsi1/lun0 mkpart primary 0% 100%
# try a sleep here to wait for the symlink
sleep 10s
mkfs -t xfs /dev/disk/azure/scsi1/lun0-part1
disk_uuid=$(blkid -o value -s UUID  /dev/disk/azure/scsi1/lun0-part1)
mkdir /mnt/cycle_server
echo "UUID=$disk_uuid /mnt/cycle_server xfs defaults,nofail 1 2" >> /etc/fstab
mount -a
ln -s /mnt/cycle_server /opt/

_tmpdir=$(mktemp -d)
pushd $_tmpdir

CS_ROOT=/opt/cycle_server

CYCLECLOUD_INSTALL_FILE_URL=${CYCLECLOUD_INSTALLER_URL}/${CYCLECLOUD_VERSION}/cyclecloud-${CYCLECLOUD_VERSION}-linux64.tar.gz

# Download the installer and install
if curl --output /dev/null --silent --head --fail "$CYCLECLOUD_INSTALL_FILE_URL"; then
    echo "Downloading CycleCloud installer from $CYCLECLOUD_INSTALL_FILE_URL"
    curl -f -L -S -o cylecloud-linux64.tar.gz "$CYCLECLOUD_INSTALL_FILE_URL"
    tar -xf cylecloud-linux64.tar.gz
    ./cycle_server/install.sh --installdir $CS_ROOT --nostart
else
  echo "Installer URL invalid does not exist: $CYCLECLOUD_INSTALL_FILE_URL"
  exit 1
fi

# Extract and install the CLI:
unzip cycle_server/tools/cyclecloud-cli.zip
pushd cyclecloud-cli-installer
./install.sh --system
popd 



# Update properties
sed -i 's/webServerMaxHeapSize\=2048M/webServerMaxHeapSize\=4096M/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerPort\=8080/webServerPort\=80/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerSslPort\=8443/webServerSslPort\=443/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerEnableHttps\=false/webServerEnableHttps=true/' $CS_ROOT/config/cycle_server.properties

# Clenaup install dir
popd
rm -rf $_tmpdir
