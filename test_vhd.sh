#! /bin/bash
os_vhd_source=$1
data_vhd_source=$2

if [ -z $os_vhd_source ];then
    echo "missing VHD source"
    exit 1
fi

if [ -z $data_vhd_source ];then
    echo "missing Data VHD source"
    exit 1
fi

echo ""
echo "Testing VHDs: "
echo "OS_VHD_SOURCE=$os_vhd_source"
echo "DATA_VHD_SOURCE=$data_vhd_source"
echo ""


config_file=config.json

function read_value {
    read $1 <<< $(jq -r "$2" $config_file)
    echo "read_value: $1=${!1}"
}

read_value location ".location"
read_value client_id ".service_principal.application_id"
read_value client_secret ".service_principal.password"
read_value tenant_id ".service_principal.tenant_id"

az login --service-principal \
    --username=$client_id \
    --password=$client_secret \
    --tenant=$tenant_id \
    --output table

tmpgroup="packertest-"$(date | md5sum | cut -c 1-10)
az group create -n $tmpgroup --location $location

az image create \
    --name ${tmpgroup}-cc \
    --resource-group $tmpgroup \
    --source $os_vhd_source \
    --os-type Linux \
    --location $location \
    --output table

az disk create -g $tmpgroup \
   --name ${tmpgroup}-cc-data-disk \
   --source $data_vhd_source

disk_id=$(az disk show -g $tmpgroup -n ${tmpgroup}-cc-data-disk --query 'id' | tr -d '"')

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
   --image ${tmpgroup}-cc \
   --attach-data-disks $disk_id \
   --admin-username azureuser \
   --ssh-key-value ~/.ssh/id_rsa.pub

