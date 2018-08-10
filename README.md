# Building a distributing a marketplace image for CycleCloud

The process for publishing a new image in Marketplace is:
1. Create an image from a VM with CycleCloud installed
2. Copy that image VHD to the storage account linked to the marketplace publisher account
3. Go to the Cloud Partner Portal to update the artifact

The scripts in this repo use packer to build an image. The image is then tested, and the VHD copied to the publishing storage account. The packer process and the deployment of the test VM is scripted, but not the VHD transfer.

The Marketplace publishing guideline recommends that a separate subscription is used to hold the marketplace-linked VHDs, and that this subscription should not be used for anything else besides holding the storage account. 

* The PM subscription is used to build the packer image and testing
* A separate marketplace subscription is used for the storage account

## Pre-requisites

These scripts below require that you have the following installed and in your PATH

1. jq 
2. packer
3. az cli (logged in)
4. Pogo credentials for both packer build VHD (this is in the PM subscription)
5. Pogo credentials for the marketplace-linked storage account (this is in a separate subscription)

You should also have a config.json file in this directory. This json file has the following structure:

```JSON
{
    "subscription_id": "PM-Subscription-Used-By-Packer", 
    "location": "eastus",
    "cyclecloud_installer_url": "https://foo.bar/cyclecloud-linux.tar.gz",
    "packer": {
        "executable": "packer"
    },
    "service_principal": {
        "name": "sp-usedby-packer-for-building-vm",
        "tenant_id":      "",
        "application_id": "",
        "password":       ""
    },
    "build": {
        "resource_group": "cyclecloud_mrktpl_image_builder",
        "storage_account": "cyclecloudimagebuilder",
        "blob_container": "imagevhds",
        "image_name": "centos75",
        "image_publisher": "OpenLogic",
        "image_offer": "CentOS",
        "image_sku": "7.5",
        "vm_size": "Standard_D2_v3"
    },
    "publish": {
        "resource_group": "cyclecloud_mrktpl_storage_account",
        "storage_account": "azurecyclecloudmrktpl",
        "image_container": "imagevhds"
    }
}


```

## Steps
1. Edit or create config.json

2. Run the build script. This launches the packer process

    ```
    ./build_image.sh
    ```

3. Test the images using the VHD_URL:

The build script outputs a URL for the VHD. To test the VHD, provide it as an input to the test script:
    ```
    ./test_vhd.sh ${VHD_URL}
    ```

3. Copy VHD to azure marketplace storage account
The target storage account is the one that is actually used for publishing. 
After verifying that the test VM using the VHD is working, copy it to the storage account for publishing:
    ```
    pogo cp az://cyclecloudimagebuilder/system/Microsoft.Compute/Images/imagevhds/${VHD_NAME} az://azurecyclecloudmrktpl/imagevhds/
    ```

4. Go to the [publishing portal](https://cloudpartner.azure.com), update the SKU with a new version




