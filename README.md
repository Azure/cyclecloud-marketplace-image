# Building a distributing a marketplace image for CycleCloud

## Disclaimer

The scripts in this repository are provided "as is" without any support from Microsoft, or CycleCloud.

This only serves as an example of how to build a CycleCloud image with Packer.

See LICENSE for further information.

## Introduction

The process for publishing a new image in Marketplace is:
1. Create a VM with an attached managed disk and install CycleCloud into the disk
2. Capture the VHD for the OS image and the managed disk
3. Launch and test a new VM usig both VHDs
4. Copy both VHDs to the storage account linked to the marketplace publisher account
5. Go to the Cloud Partner Portal to update the artifact

The scripts in this repo use packer to build the images. These are then tested and the VHDs copied to the publishing storage account. The packer process, the deployment of the test VM, and the VHD transfer are scripted. 

The Marketplace publishing guideline recommends that a separate subscription is used to hold the marketplace-linked VHDs, and that this subscription should not be used for anything else besides holding the storage account. 

* The PM subscription is used to build the packer image and testing
* A separate marketplace subscription is used for the storage account

## Pre-requisites

The scripts used require the following installed in your PATH

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
    "cyclecloud_installer_url": "https://cyclecloudarm.blob.core.windows.net/cyclecloudrelease",
    "cyclecloud_version": "7.6.0",
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
        "image_container": "imagevhds",
        "storage_key": "ACCESSKEY-For-StorageAccount",
    }
}


```

## Steps


1. Create a User-Assigned Managed Identity with permissions to create the Builder VM and Storage Blob Contributor to the local Storage Account
   1. **WARNING** If you builder VM will have multiple assigned Managed IDs, you must specify the client_id of the MI to use.
2. Create a Blob container named ```imagevhds``` in the local Storage Account
3. Upload the mpimagebuilder project:

```bash
cd mpimagebuilder
cyclecloud project upload <locker_name>
```

3. Import the mpimagebuilder cluster template to CycleCloud

```bash
cyclecloud import_template -f ./templates/mpimagebuilder.txt
```

4. Create a new mpimagebuilder cluster with the new User-Assigned Managed Identity set

5. Edit or create config.json
  - Replace cyclecloud_version with the version to be pushed
  - fill in the service principal used for the packer build
  - fill in the storage_key for the Marketplace Storage Account

6. Run the build script. This launches the packer process

    ```
    ./build_image.sh
    ```

    - The script will output the OS_VHD_URL and DATA_VHD_URL






7. Test the images using the VHD URLs:

The build script outputs the URLs for the VHDs. To test the VHDs, provide them as input to the test script:
    ```
    ./test_cc_image.sh ${OS_IMAGE_RESOURCE_ID}
    ```

The test script will launch a VM and run a few cursory automated tests.

IMPORTANT:  
Clean up the temporary VM and Resource Group after testing.
az group delete -n ${tmpgroup} --no-wait

3. Locate the new Managed Image in the Azure Portal.

4. Navigate to the Azure Compute Gallery which will hold the image in the Azure Portal.  Add a new Image version using the new Managed Image.
   1. Currently this is a manual process.   The "deploy_vhd.sh" script is no longer used.

5. Go to the [publishing portal](https://partner.microsoft.com/en-us/dashboard/commercial-marketplace/overview), update the SKU with a new version and VHD artifacts

6. See [CycleCloud Publishing](https://microsoft.sharepoint.com/:w:/t/CycleEngineeringTeam/EYORK6cI7ExGrFHGXIrOHrAB5WNvPRaOkq0VBiM0bD4-WA?e=pMBt6l) for
details on how to use the Marketplace Portal.


