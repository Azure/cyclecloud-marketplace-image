#!/bin/bash
set -ex

# We tag the Distribution with MP Image Version string to differentiate multiple Marketplace
# image builds of the same (or different) CycleCloud Releases in telemetry
CC_MARKETPLACE_VERSION=${1}
REPO_STREAM=${2:-"prod"}
CC_PACKAGE_NAME=${3}

function version_less_than_850 {
   cat << EOF | sort -V -C
$CC_MARKETPLACE_VERSION
8.5.0
EOF
}

# Workaround for CVE-2023-32233 (disable user namespaces)
echo user.max_user_namespaces=0 > /etc/sysctl.d/userns.conf
sysctl -p /etc/sysctl.d/userns.conf

yum -y update --security

yum install -y tree policycoreutils-python-utils wget jq

# Adding dnsmasq for helping with locked-down installs
yum install -y dnsmasq

# install AZ CLI
rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat > /etc/yum.repos.d/azure-cli.repo <<EOF
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

yum install -y azure-cli


if [[ $REPO_STREAM == "insiders" ]]; then
   BASE_URL=https://packages.microsoft.com/yumrepos/cyclecloud-insiders
else
   BASE_URL=https://packages.microsoft.com/yumrepos/cyclecloud
fi

cat > /etc/yum.repos.d/cyclecloud.repo <<EOF
[cyclecloud]
name=cyclecloud
baseurl=$BASE_URL
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# show available disks
tree /dev/disk/azure

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
export CS_HOME=${CS_ROOT}

# Configure SELinux to allow CycleCloud to run from non-standard bin directory
chcon -R -t bin_t ${CS_HOME}
semanage fcontext -a -t bin_t "${CS_HOME}(/.*)?"
restorecon -r -v ${CS_HOME}

# explicitly install java 8 before cyclecloud (to ensure environment is set)
yum -y install java-1.8.0-openjdk-headless

if [[ -n $CC_PACKAGE_NAME ]]; then
   yum -y install ${CC_PACKAGE_NAME}
else
   yum -y install cyclecloud8-${CC_MARKETPLACE_VERSION}
fi

# # Update python to 3.9 or later for latest openssl and cryptography support
# # Required for CycleCloud CLI
# yum -y install python39 python39-pip
# alternatives --set python /usr/bin/python3.9
# alternatives --set python3 /usr/bin/python3.9
python3 -m pip install --upgrade pip

# create a data record to identify this installation as a Marketplace VM
cat > /opt/cycle_server/config/data/marketplace_distribution.txt <<EOF
AdType = "Application.Setting"
Name = "distribution_method"
Value = "marketplace:${CC_MARKETPLACE_VERSION}"
EOF

/opt/cycle_server/cycle_server await_startup

# Configure CycleCloud as a system service
/opt/cycle_server/system/scripts/autostart.sh
systemctl daemon-reload

# Clear the site_id
/opt/cycle_server/cycle_server execute 'update Application.Setting set Value = undefined where Name == "site_id" || Name == "reported_version"'

# Extract and install the CLI:
if version_less_than_850; then
   echo "CycleCloud version is less than 8.5.0, CLI install may be incompatible with system python"
   # Update python to 3.9 or later for latest openssl and cryptography support
   # Required for CycleCloud CLI
   yum -y install python39 python39-pip
   alternatives --set python /usr/bin/python3.9
   alternatives --set python3 /usr/bin/python3.9
   python3 -m pip install --upgrade pip

   unzip $CS_ROOT/tools/cyclecloud-cli.zip
   pushd cyclecloud-cli-installer
   cp /tmp/install_cli.py ./install.py   # Monkeypatch the installer with pip update for python 3.6.0
   ./install.sh --system
   popd
else
   tar xzf $CS_ROOT/tools/cyclecloud-cli-linux-amd64.tar.gz
   pushd cyclecloud-cli-installer
   ./install.sh -y
   popd 
fi

# Update properties
sed -i 's/webServerMaxHeapSize\=2048M/webServerMaxHeapSize\=4096M/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerPort\=8080/webServerPort\=80/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerSslPort\=8443/webServerSslPort\=443/' $CS_ROOT/config/cycle_server.properties
sed -i 's/webServerEnableHttps\=false/webServerEnableHttps=true/' $CS_ROOT/config/cycle_server.properties

# Add Prometheus JMX exporter
curl -o /tmp/jmx_prometheus_javaagent-1.0.1.jar 'https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/1.0.1/jmx_prometheus_javaagent-1.0.1.jar'
echo "7d61f737fd661610ccc14aea79764faa1ea94a340cbc8f0029b3d2edea3d80c1  /tmp/jmx_prometheus_javaagent-1.0.1.jar" | sha256sum -c
mv /tmp/jmx_prometheus_javaagent-1.0.1.jar ${CS_ROOT}/jmx_prometheus_javaagent.jar
chown cycle_server:cycle_server ${CS_ROOT}/jmx_prometheus_javaagent.jar

cat << EOF > ${CS_ROOT}/prometheus_exporter_config.yaml
rules:
- pattern: ".*"
EOF
chown cycle_server:cycle_server ${CS_ROOT}/prometheus_exporter_config.yaml


# CRITICAL: DO THIS IMMEDIATELY BEFORE STOPPING CC and BAKING
# Cleanup initial shared cyclecloud creds
# If this step fails, the image may be baked with fixed credetials for ALL USERS!
# Do NOT restart CycleCloud after this step or credentials may be regenerated
chmod a+x /tmp/do_generalize.sh
yes | /tmp/do_generalize.sh
systemctl stop cycle_server

if ls -l /opt/cycle_server/.ssh/*.pem; then
   echo "WARNING: Failed to generalize!" >&2
   exit -1
fi

# Clenaup install dir
popd
rm -rf $_tmpdir

