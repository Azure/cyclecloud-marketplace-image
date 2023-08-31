#! /bin/bash
managed_image_id=$1

if [ -z $managed_image_id ];then
    echo "missing Managed Image resource id"
    exit 1
fi

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

# login with managed identity
az login -i --output table

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
   --admin-username azureuser \
   --ssh-key-value ~/.ssh/id_rsa.pub

echo ""
echo "IMPORTANT: Delete the resource group after testing to avoid leaking a VM!"
echo "Command:  "
echo "      az group delete -n $tmpgroup --no-wait"
echo ""
