#!/bin/bash
set -ex
yum -y update --security


cat > /etc/yum.repos.d/cyclecloud.repo <<EOF
[cyclecloud]
name=cyclecloud
baseurl=https://packages.microsoft.com/yumrepos/cyclecloud
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# mount data disk
parted /dev/disk/azure/scsi1/lun0 --script -- mklabel gpt
parted -a optimal /dev/disk/azure/scsi1/lun0 mkpart primary 0% 100%
# try a sleep here to wait for the symlink
sleep 10s
mkfs -t xfs /dev/disk/azure/scsi1/lun0-part1
disk_uuid=$(blkid -o value -s UUID  /dev/disk/azure/scsi1/lun0-part1)
mkdir /opt/cycle_server
echo "UUID=$disk_uuid /opt/cycle_server xfs defaults,nofail 1 2" >> /etc/fstab
mount -a

_tmpdir=$(mktemp -d)
pushd $_tmpdir

CS_ROOT=/opt/cycle_server

yum -y install cyclecloud

/opt/cycle_server/cycle_server await_startup

systemctl stop cycle_server

# Extract and install the CLI:

unzip $CS_ROOT/tools/cyclecloud-cli.zip
pushd cyclecloud-cli-installer
./install.sh --system
popd 


# Update properties
sed -i 's/webServerMaxHeapSize\=2048M/webServerMaxHeapSize\=4096M/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerPort\=8080/webServerPort\=80/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerSslPort\=8443/webServerSslPort\=443/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerEnableHttps\=false/webServerEnableHttps=true/' $CS_ROOT/config/cycle_server.properties


# create a data record to identify this installation as a Marketplace VM
cat > /opt/cycle_server/config/data/dist_method.txt <<EOF
Category = "system"
Status = "internal"
AdType = "Application.Setting"
Description = "CycleCloud distribution method e.g. marketplace, container, manual."
Value = "marketplace"
Name = "distribution_method"
EOF


# Clenaup install dir
popd
rm -rf $_tmpdir
