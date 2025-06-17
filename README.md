# Building a distributing a marketplace image for CycleCloud

## Disclaimer

The scripts in this repository are provided "as is" without any support from Microsoft, or CycleCloud.

This only serves as an example of how to build a CycleCloud image with Packer.

See LICENSE for further information.

## Building the Image

To build a new image which replicates the CycleCloud Marketplace image:
1. Start a Virtual Machine from Azure Marketplace or Cyclecloud with Ubuntu OS image.You need to install docker if starting a VM from Azure directly. 
2. Create at least one Resource Group, Virtual Network and Subnet in which to build the image
3. Create a User-Assigned Managed ID with permissions to create the Builder VM and Storage Blob Contributor to the CycleCloud Locker Storage Account
4. (Optionally) Create a Compute Image Gallery to hold the built images
5. SSH to the VM
6. Clone this repository
7.  Become root and go to the build directory:
``` bash
sudo -i
cd /opt/cycle/cyclecloud-marketplace-image/
```
1. Copy or rename config.sample.json to config.json and fill in the config.json details:
   1. Replace cyclecloud_version with the version to be pushed
   2. Fill in the target subscription_id used for the packer build
   3. Fill in the target image_gallery for publishing (optional)
   4. Fill in the base VM image offer details
   5. Fill in the user_assigned_identity_client_id of the User Assigned Managed Identity.
   6. Fill repo_stream from where to install CC: insiders, insiders-fast or prod. (optional, defualt: prod)
   7. If repo_stream is insiders-fast it will use local package which needs to be specified in 
      cyclecloud_package_name (optional) If using this option you need to place the package in cyclecloud_local folder. 

2. You can build the image by running docker-build.sh script after updating config.json file. This will print the OS_IMAGE_RESOURCE_ID
```
  ./docker-build.sh
```
You can check the logs in logs/packer*log file

3. You can run tests using docker-run-tests.sh file 
```
./docker-run-tests.sh <OS_IMAGE_RESOURCE_ID>
```
## Building the Image inside Container

Run the build script. This launches the packer process
 ``` 
    ./build_image.sh [-t]
 ```
 1. The script will output the OS_VHD_URL and DATA_VHD_URL
 2. Use the "-t" option to automatically run the image tests

## Testing the Image inside Container

Test the new image using the Image Resource ID:

The build script outputs the Resource ID for the new image. 
To test the image as part of the build, use the "-t" option to `build_image.sh`.
To (re-)test the image directly provide the Image Resource ID as input to the test script:
 ``` 
    ./test_cc_image.sh [-d] ${OS_IMAGE_RESOURCE_ID}
 ```
 1. The script will output the command to manually clean up the test resources.
 2. Use the "-d" option to automatically delete the test resources.

The test script will launch a VM and run a few cursory automated tests.

IMPORTANT:  
If the "-d" option was not used, then clean up the temporary VM and Resource Group after testing.
az group delete -n ${tmpgroup} --no-wait

## Deploying the Image

1. Locate the new Managed Image in the Azure Portal using the new Image Resource ID.

2. Navigate to the Azure Compute Gallery which will hold the image in the Azure Portal.  Add a new Image version using the new Managed Image.
   1. Currently this is a manual process.   The "deploy_vhd.sh" script is no longer used.

3. Go to the [publishing portal](https://partner.microsoft.com/en-us/dashboard/commercial-marketplace/overview), update the SKU with a new version and VHD artifacts

4. See [CycleCloud Publishing](https://microsoft.sharepoint.com/:w:/t/CycleEngineeringTeam/EYORK6cI7ExGrFHGXIrOHrAB5WNvPRaOkq0VBiM0bD4-WA?e=pMBt6l) for
details on how to use the Marketplace Portal.
