# Building a distributing a marketplace image for CycleCloud

## Disclaimer

The scripts in this repository are provided "as is" without any support from Microsoft, or CycleCloud.

This only serves as an example of how to build a CycleCloud image with Packer.

See LICENSE for further information.

## Introduction

TODO : build image in existing VNet without public IP: https://github.com/hashicorp/packer/issues/10046#issuecomment-719549290

To build a new image which replicates the CycleCloud Marketplace image:
1. Start and configure a CycleCloud instance from Marketplace
2. Create a User-Assigned Managed ID with permissions to create the Builder VM and Storage Blob Contributor to the CycleCloud Locker Storage Account
3. (Optionally) Create a Compute Image Gallery to hold the built images
4. Clone this repository
5. Upload the mpimagebuild project to your Storage Locker
``` bash
cd mpimagebuilder
cyclecloud project upload <locker_name>
```
1. Import the ``mpimagebuilder`` cluster template to CycleCloud
``` bash
cyclecloud import_template -f templates/mpimagebuilder.txt
```
1. From the CycleCloud GUI, create a new mpimagebuild cluster with:
   1. The User-Assigned Managed ID created above
   2. An Ubuntu VM image
2. Start the cluster and wait for the ``builder`` VM to go to the ``Running`` (green) state
3. SSH to the ``builder`` VM
4.  Become root and go to the build directory:
``` bash
sudo -i
cd /opt/cycle/cyclecloud-marketplace-image/
```
5. Copy or rename config.sample.json to config.json and fill in the config.json details:
   1. Replace cyclecloud_version with the version to be pushed
   2. Fill in the target subscription_id used for the packer build
   3. Fill in the target image_gallery for publishing (optional)
   4. Fill in the base VM image offer details
6. . Run the build script. This launches the packer process
``` bash
./build_image.sh
```
    1. The script will output the OS_VHD_URL and DATA_VHD_URL






1. Test the images using the VHD URLs:

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


