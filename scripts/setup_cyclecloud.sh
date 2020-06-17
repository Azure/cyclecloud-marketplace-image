#!/bin/bash
set -ex
dnf -y update --security

# Adding dnsmasq for helping with locked-down installs
dnf install -y dnsmasq


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
restorecon -r /opt

dnf -y install cyclecloud8

# create a data record to identify this installation as a Marketplace VM
cat > /opt/cycle_server/config/data/marketplace_site_id.txt <<EOF
AdType = "Application.Setting"
Name = "site_id"
Value = "marketplace"

AdType = "Application.Setting"
Name = "distribution_method"
Value = "marketplace"
EOF

/opt/cycle_server/cycle_server await_startup

/opt/cycle_server/cycle_server execute 'update Application.Setting set Value = undefined where Name == "site_id" || Name == "reported_version"'

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


# Clenaup install dir
popd
rm -rf $_tmpdir

systemctl stop cycle_server
