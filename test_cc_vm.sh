#!/bin/bash
# Allows re-running the tests without recreating the VM

set -x
resource_group=$1
vm_resource_name=${2}

if [ -z $resource_group ];then
    echo "missing resource group"
    exit 1
fi


if [ -z $vm_resource_name ];then
    vm_resource_name=${1}-cc-vm
    echo "Using VM resource name: $vm_resource_name"
fi

if [ ! -f ~/.ssh/id_rsa.pub ]; then
   echo "Missing ssh keypair..."
   exit 1
fi


echo ""
echo "Testing VM: "

echo "resource_group=$resource_group"
echo "vm_resource_name=$vm_resource_name"
echo ""


config_file=config.json

function read_value {
    read $1 <<< $(jq -r "$2" $config_file)
    echo "read_value: $1=${!1}"
}

read_value location ".location"
read_value subscription_id ".subscription_id"
read_value user_assigned_identity_client_id ".user_assigned_identity_client_id"

# login with managed identity
az login --identity --client-id ${user_assigned_identity_client_id}

# ensure we're using the subscription that holds the image

az account set -s "${subscription_id}"


echo "Running Automated test..."

# Verify jsvc process here
az vm run-command invoke -g ${resource_group} -n ${vm_resource_name} --command-id RunShellScript --scripts  "ps aux | grep '[j]svc'" > ./check_jsvc.json

# Verify Cyclecloud checks
az vm run-command invoke -g ${resource_group} -n ${vm_resource_name} --command-id RunShellScript --scripts @scripts/run_cc_vm_checks.sh > ./test_cc_vm.json
if [ $(cat ./test_cc_vm.json | jq '.value[0].code') != '"ProvisioningState/succeeded"' ]; then
    echo "ERROR: Automated test command failed..."
fi
cat ./check_jsvc.json | jq '.value[0].message'
if ! grep -q "jsvc.exec" ./check_jsvc.json; then
   echo "ERROR: jsvc not found."
fi
cat ./test_cc_vm.json | jq '.value[0].message'
if ! grep -q "ready[.]\+ready" ./test_cc_vm.json; then
   echo "ERROR: CycleCloud not started."
fi
if ! grep -q "Azure CycleCloud" ./test_cc_vm.json; then
   echo "ERROR: Failed curl to CycleCloud."
fi
if ! grep -q "body><\/body" ./test_cc_vm.json; then
   echo "ERROR: CycleCloud health_monitor returned unexpected result."
fi
if ! grep -q "Usage: cyclecloud initialize" ./test_cc_vm.json; then
   echo "ERROR: CycleCloud CLI not found."
fi


echo "Automated test passed.   See ./test_cc_vm.json for details."

