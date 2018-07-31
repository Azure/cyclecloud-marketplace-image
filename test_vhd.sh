#! /bin/bash
vhd_source=$1
if [ -z $vhd_source ];then
    echo "missing VHD source"
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
echo $tmpgroup
az group create -n $tmpgroup --location $location

az image create \
    --name ${tmpgroup}-cc \
    --resource-group $tmpgroup \
    --source $vhd_source \
    --os-type Linux \
    --location $location \
    --output table

az vm create \
   --resource-group $tmpgroup \
   --name ${tmpgroup}-cc-vm \
   --image ${tmpgroup}-cc
   --admin-username azureuser \
   --ssh-key-value ~/.ssh/id_rsa.pub
