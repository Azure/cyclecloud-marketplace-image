#! /bin/bash
managed_image_id=$1

if [ -z $managed_image_id ];then
    echo "missing Managed Image resource id"
    exit 1
fi

if [ ! -f ~/.ssh/id_rsa.pub ]; then
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
fi

# Ensure that az cli is installed
sudo apt install --upgrade -y azure-cli

echo ""
echo "Testing Image: "

echo "OS_IMAGE_RESOURCE_ID=$managed_image_id"
echo ""


config_file=config.json

function read_value {
    read $1 <<< $(jq -r "$2" $config_file)
    echo "read_value: $1=${!1}"
}

read_value location ".location"
read_value subscription_id ".subscription_id"

# login with managed identity
az login -i --output table

# ensure we're using the subscription that holds the image

az account set -s "${subscription_id}"

tmpgroup="packertest-"$(date | md5sum | cut -c 1-10)
az group create -n $tmpgroup --location $location

# az image create \
#     --name ${tmpgroup}-cc \
#     --resource-group $tmpgroup \
#     --source $os_vhd_source \
#     --os-type Linux \
#     --location $location \
#     --output table

# az disk create -g $tmpgroup \
#    --name ${tmpgroup}-cc-data-disk \
#    --source $data_vhd_source

# disk_id=$(az disk show -g $tmpgroup -n ${tmpgroup}-cc-data-disk --query 'id' | tr -d '"')

az network nsg create -g $tmpgroup -n ${tmpgroup}-nsg 

az network nsg rule create -g $tmpgroup \
                           --nsg-name ${tmpgroup}-nsg \
                           --name ${tmpgroup}-nsg-web \
                           --access Allow \
                           --destination-port-ranges 22 80 443 \
                           --direction Inbound \
                           --priority 101

az vm create \
   --resource-group $tmpgroup \
   --name ${tmpgroup}-cc-vm \
   --nsg ${tmpgroup}-nsg \
   --image ${managed_image_id} \
   --public-ip-address "" \
   --admin-username azureuser \
   --ssh-key-value ~/.ssh/id_rsa.pub

echo "Waiting for provisioning success..."
sleep 5
until [ $( az vm show -g ${tmpgroup} -n ${tmpgroup}-cc-vm | jq '.provisioningState' ) == '"Succeeded"' ]; do
    echo "."
    sleep 5
done

echo "VM Provisioned.  Sleeping to allow cyclecloud to start..."
sleep 60

echo "Running Automated test..."
bash -c "./test_cc_vm.sh $tmpgroup ${tmpgroup}-cc-vm"

echo ""
echo "IMPORTANT: Delete the resource group after testing to avoid leaking a VM!"
echo "Command:  "
echo "      az group delete -n $tmpgroup --no-wait"
echo ""
