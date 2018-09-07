#! /bin/bash
image_vhd_source=$1
data_vhd_source=$2

if [ -z $image_vhd_source ];then
    echo "missing VHD source"
    exit 1
fi

if [ -z $data_vhd_source ];then
    echo "missing Data VHD source"
    exit 1
fi

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
    --source $image_vhd_source \
    --os-type Linux \
    --location $location \
    --output table

az disk create -g $tmpgroup \
   --name ${tmpgroup}-cc-data-disk \
   --source $data_vhd_source

disk_id=$(az disk show -g $tmpgroup -n ${tmpgroup}-cc-data-disk --query 'id' | tr -d '"')

az vm create \
   --resource-group $tmpgroup \
   --name ${tmpgroup}-cc-vm \
   --image ${tmpgroup}-cc \
   --attach-data-disks $disk_id \
   --admin-username azureuser \
   --ssh-key-value ~/.ssh/id_rsa.pub

