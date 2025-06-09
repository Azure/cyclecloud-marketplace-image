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
   6. Fill repo_stream from where to install CC: insiders, local or prod. (optional, defualt: prod)
   7. If repo_stream is local it will use local package which needs to be specified in 
      cyclecloud_package_name (Optional) If using this option you need to place the package in cyclecloud_local folder. 

2. You can build a docker container in stages. Here is the list of stages:
   1. **add_project**: This stage basically add files from current directory which is cyclecloud-marketplace-image to docker folder.
   2. **install_deps**: This stage install dependencies to build an image by running install-dep.sh script
   3. **build_image**: This stage runs the build_image.sh script. 
   4. **test_cc_image**: This stage tests the cc image in addition to building.
   5. **run_test_on_existing_image** : If you only wish to run tests on existing image then you can pass an ARG OS_IMAGE_RESOURCE_ID and run tests.  
   
   docker build -t cc_marketplace_build -f Dockerfile.Ubuntu . --target <stage>

   docker build --build-arg OS_IMAGE_RESOURCE_ID="<Resource-id of image>" -t cc_marketplace_build -f Dockerfile.Ubuntu . --target run_test_on_existing_image
   
   If you want to verify the build logs as they are not stored by docker once build is complete you can store in build.log file and check later. 

   docker build -t cc_marketplace_build -f Dockerfile.Ubuntu . --target <stage> > build.log 2>&1
  
   At any stage to debug you can start the docker container with below command and run the remaining scripts manually:
   docker run -it cc_marketplace_build bash

**Here are the details of running scripts inside a container**

1. . Run the build script. This launches the packer process
``` bash
./build_image.sh [-t]
```
    1. The script will output the OS_VHD_URL and DATA_VHD_URL
    2. Use the "-t" option to automatically run the image tests

## Testing the Image

2. Test the new image using the Image Resource ID:

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