#! /bin/bash
vhd_source=$1
if [ -z $vhd_source ];then
    echo "missing VHD source"
    exit 1
fi
tmpgroup="packertest-"$(date | md5sum | cut -c 1-10)
echo $tmpgroup
az group create -n $tmpgroup --location eastus

az image create \
    --name ${tmpgroup}-cc \
    --resource-group $tmpgroup \
    --source $vhd_source \
    --os-type Linux \
    --location eastus \
    --output table

az vm create \
   --resource-group $tmpgroup \
   --name ${tmpgroup}-cc-vm \
   --image ${tmpgroup}-cc
   --admin-username azureuser \
   --ssh-key-value ~/.ssh/id_rsa.pub
