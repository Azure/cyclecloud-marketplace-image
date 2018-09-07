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

read_value storage_account ".publish.storage_account"
read_value storage_key ".publish.storage_key"
read_value image_container ".publish.image_container"

echo ""
echo "####"
echo "Copying the OS VHD into the publishing storage account: $storage_account, container: $image_container" 
pogo cp $image_vhd_source az://${storage_account}/${image_container}/ 
echo ""
echo "Generating SAS key for the new VHD"

conn="DefaultEndpointsProtocol=https;AccountName=$storage_account;AccountKey=$storage_key"

start_date=$(date +%Y-%m-%d -d "yesterday")T00:00:00Z
end_date=$(date +%Y-%m-%d -d "+30 day")T00:00:00Z
sas_key=$(az storage container generate-sas -n $image_container --permissions rl --start $start_date --expiry $end_date --connection-string $conn | tr -d '"') 

echo "SAS Key: $sas_key"
echo ""

image_vhd_name=$(echo $image_vhd_source | awk -F "/" '{print $NF}')

publish_image_vhd_url=https://${storage_account}.blob.core.windows.net/${image_container}/${image_vhd_name}?${sas_key}


echo ""
echo "####"
echo "Copying the Data VHD into the publishing storage account: $storage_account, container: $image_container" 
pogo cp $data_vhd_source az://${storage_account}/${image_container}/ 
echo ""
echo "Generating SAS key for the new data VHD"

conn="DefaultEndpointsProtocol=https;AccountName=$storage_account;AccountKey=$storage_key"

data_vhd_name=$(echo $data_vhd_source | awk -F "/" '{print $NF}')

publish_data_vhd_url=https://${storage_account}.blob.core.windows.net/${data_container}/${data_vhd_name}?${sas_key}




echo ""
echo "####"
echo "VHDs Publish URL:"
echo "OS Image: $publish_image_vhd_url"
echo "Data Image: $publish_data_vhd_url"
echo "####"




