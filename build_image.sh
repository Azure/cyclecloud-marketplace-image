#!/bin/bash

set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

config_file="config.json"

function usage(){
    me=$(basename "$0")
    echo ""
    echo "Usage:"
    echo "$me -c config.json -t"
    echo "    -c: config file to use"
    echo "    -t: run tests automatically"
    echo "    -h: help"
    echo ""
}

run_tests=0
while getopts ":tc:h" OPTION; do
    case ${OPTION} in
    c) config_file=$OPTARG
    ;;
    t) run_tests=1
    ;;
    h) usage
       exit 0
    ;;
    \?) echo "Invalid option: -$OPTARG" >&2
        exit 1
    ;;
    :) echo "Option -$OPTARG requires an argument." >&2
       exit 1
    ;;
    esac
done

shift $(( OPTIND - 1 ));

echo "config file: $config_file"

function read_value {
    read $1 <<< $(jq -r "$2" $config_file)
    echo "read_value: $1=${!1}"
}

read_value location ".location"
read_value subscription_id ".subscription_id"
read_value resource_group ".resource_group"
read_value build_resource_group_name ".build_resource_group_name"
read_value virtual_network_name ".virtual_network_name"
read_value virtual_network_subnet_name ".virtual_network_subnet_name"
read_value virtual_network_resource_group_name ".virtual_network_resource_group_name"

read_value build_image_name ".build.image_name"
read_value build_image_publisher ".build.image_publisher"
read_value build_image_offer ".build.image_offer"
read_value build_image_sku ".build.image_sku"
read_value build_vm_size ".build.vm_size"
read_value cyclecloud_version ".cyclecloud_version"
read_value cyclecloud_package_name ".cyclecloud_package_name"

timestamp=$(date +%Y%m%d-%H%M%S)

# run packer
pushd ./packer
packer_log=packer-output-$timestamp.log
packer init ./ccmarketplace.pkr.hcl | tee $packer_log
packer build \
    -var location=$location \
    -var subscription_id=$subscription_id \
    -var resource_group=$resource_group \
    -var build_resource_group_name=$build_resource_group_name \
    -var virtual_network_name=$virtual_network_name \
    -var virtual_network_subnet_name=$virtual_network_subnet_name \
    -var virtual_network_resource_group_name=$virtual_network_resource_group_name \
    -var image_name=$build_image_name \
    -var image_publisher=$build_image_publisher \
    -var image_offer=$build_image_offer \
    -var image_sku=$build_image_sku \
    -var vm_size=$build_vm_size \
    -var cyclecloud_version=$cyclecloud_version \
    -var cyclecloud_package_name=$cyclecloud_package_name \
    . \
    | tee -a ../$packer_log

if [ $? != 0 ]; then
    echo "ERROR: Bad exit status for packer"
    exit 1
fi
popd

# get new Managed Image from the packer output
managed_image_id="$(grep -Po '(?<=ManagedImageId\: )[^$]*' ${packer_log})"
export OS_IMAGE_RESOURCE_ID=$managed_image_id
env > /tmp/build_image_env.env

if [ ${run_tests} -eq 1 ]; then
    echo "Running automated tests for image ${managed_image_id}"
    echo ""
    echo "To re-run the tests manually:"
    echo "OS_IMAGE_RESOURCE_ID=${managed_image_id}"
    echo "./test_cc_image.sh \${OS_IMAGE_RESOURCE_ID}"
    echo ""
    ./test_cc_image.sh -d "${managed_image_id}"
else
    set +x
    echo ""
    echo ""
    echo "#################################"
    echo ""
    echo "Packer log file: $packer_log"
    echo ""
    echo "To complete the deploy process set the environment variables:"
    echo "OS_IMAGE_RESOURCE_ID=$managed_image_id"
    echo ""
    echo "Test the images:"
    echo "./test_cc_image.sh \${OS_IMAGE_RESOURCE_ID}"
    echo ""
    echo "Deploy to the publishing account:"
    echo "./deploy_vhd.sh \${OS_IMAGE_RESOURCE_ID}"
    echo ""
    echo "#################################"
fi
