# Building a distributing a marketplace image for CycleCloud

## Steps
1. Run the build script
./build_image.sh
- Build script outputs a VHD_URL.

2. Test the images using the VHD_URL:
./test_vhd.sh ${VHD_URL}

3. If tests pass, copy the VHD to the marketplace storage account:
pogo cp az://cyclecloudimagebuilder/system/Microsoft.Compute/Images/imagevhds/${VHD_NAME} az://azurecyclecloudmrktpl/imagevhds/


