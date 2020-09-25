#! /bin/bash
os_vhd_source=$1
data_vhd_source=$2

logfile=vhd_deploy.$(date +%s).log

exec &> >(tee -a "$logfile")
echo "This will be logged to the file and to the screen"


if [ -z $os_vhd_source ];then
    echo "missing VHD source"
    exit 1
fi

if [ -z $data_vhd_source ];then
    echo "missing Data VHD source"
    exit 1
fi


echo ""
echo "Deploying VHDs: "
echo "OS_VHD_SOURCE=$os_vhd_source"
echo "DATA_VHD_SOURCE=$data_vhd_source"
echo ""


config_file=config.json

function read_value {
    read $1 <<< $(jq -r "$2" $config_file)
    echo "read_value: $1=${!1}"
}

read_value storage_account ".publish.storage_account"
read_value storage_key ".publish.storage_key"
read_value image_container ".publish.image_container"
read_value source_storage_key ".build.storage_key"

echo ""
echo "####"
echo "Copying the OS VHD into the publishing storage account: $storage_account, container: $image_container" 

image_vhd_name=$(echo $os_vhd_source | awk -F "/" '{print $NF}')
image_destination_url=https://${storage_account}.blob.core.windows.net/${image_container}/${image_vhd_name}

azcopy --source-key $source_storage_key --dest-key $storage_key  --source $os_vhd_source --destination $image_destination_url

echo ""
echo "Generating SAS key for the new VHD"

conn="DefaultEndpointsProtocol=https;AccountName=$storage_account;AccountKey=$storage_key"

start_date=$(date +%Y-%m-%d -d "yesterday")T00:00:00Z
end_date=$(date +%Y-%m-%d -d "+30 day")T00:00:00Z
sas_key=$(az storage container generate-sas -n $image_container --permissions rl --start $start_date --expiry $end_date --connection-string $conn | tr -d '"') 

echo "SAS Key: $sas_key"
echo ""

publish_image_vhd_url=https://${storage_account}.blob.core.windows.net/${image_container}/${image_vhd_name}?${sas_key}


echo ""
echo "####"
echo "Copying the Data VHD into the publishing storage account: $storage_account, container: $image_container" 

data_vhd_name=$(echo $data_vhd_source | awk -F "/" '{print $NF}')
data_vhd_destination_url=https://${storage_account}.blob.core.windows.net/${image_container}/${data_vhd_name}

azcopy --source-key $source_storage_key --dest-key $storage_key  --source $data_vhd_source --destination $data_vhd_destination_url
#pogo cp $data_vhd_source az://${storage_account}/${image_container}/ 

echo ""
echo "Generating SAS key for the new data VHD"

conn="DefaultEndpointsProtocol=https;AccountName=$storage_account;AccountKey=$storage_key"

publish_data_vhd_url=https://${storage_account}.blob.core.windows.net/${image_container}/${data_vhd_name}?${sas_key}




echo ""
echo "####"
echo "VHDs Publish URL:"
echo "OS Image: $publish_image_vhd_url"
echo "Data Image: $publish_data_vhd_url"
echo "####"


