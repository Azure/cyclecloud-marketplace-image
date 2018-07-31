#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

config_file="config.json"

function usage(){
    me=`basename $0`
    echo ""
    echo "Usage:"
    echo "$me -c config.json "
    echo "    -c: config file to use"
    echo "    -h: help"
    echo ""
}

while getopts "a: c: h" OPTION
do
    case ${OPTION} in
        c)
        config_file=$OPTARG
            ;;
        h)
        usage
        exit 0
            ;;
    esac
done

shift $(( OPTIND - 1 ));

echo "config file: $config_file"

function read_value {
    read $1 <<< $(jq -r "$2" $config_file)
    #echo "read_value: $1=${!1}"
}

read_value subscription_id ".subscription_id"
read_value location ".location"
read_value client_id ".service_principal.application_id"
read_value client_secret ".service_principal.password"
read_value tenant_id ".service_principal.tenant_id"
read_value publish_rg ".publish.resource_group"
read_value publish_storage ".publish.storage_account"
read_value build_image_name ".build.image_name"
read_value build_image_publisher ".build.image_publisher"
read_value build_image_offer ".build.image_offer"
read_value build_image_sku ".build.image_sku"
read_value build_vm_size ".build.vm_size"
read_value build_storage_account ".build.storage_account"
read_value build_container ".build.blob_container"
read_value build_rg ".build.resource_group"
read_value cyclecloud_installer_url ".cyclecloud_installer_url"

timestamp=$(date +%Y%m%d-%H%M%S)

cyclecloud_install_script="./scripts/setup_cyclecloud.sh"
# run packer
packer_log=packer-output-$timestamp.log
packer build \
    -var subscription_id=$subscription_id \
    -var location=$location \
    -var resource_group=$build_rg \
    -var storage_account=$build_storage_account \
    -var blob_container=$build_container \
    -var tenant_id=$tenant_id \
    -var client_id=$client_id \
    -var client_secret=$client_secret \
    -var image_name=$image_name \
    -var image_publisher=$image_publisher \
    -var image_offer=$image_offer \
    -var image_sku=$image_sku \
    -var vm_size=$vm_size \
    -var cyclecloud_install_script=$cyclecloud_install_script \
    -var cyclecloud_installer_url=$cyclecloud_installer_url \
    packer/build.json \
    | tee $packer_log

if [ $? != 0 ]; then
    echo "ERROR: Bad exit status for packer"
    exit 1
fi


# get vhd source from the packer output
vhd_source="$(grep -Po '(?<=OSDiskUri\: )[^$]*' $packer_log)"

echo $vhd_source 

echo $packer_log

