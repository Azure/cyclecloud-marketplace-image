

# Check if OS_IMAGE_RESOURCE_ID is passed
if [ -z "$1" ]; then
  echo "Usage: Missing OS_IMAGE_RESOURCE_ID"
  exit 1
fi

OS_IMAGE_RESOURCE_ID="$1"

CONTAINER_IMAGE="cc_marketplace_image_builder"
BUILD_DIR="$(dirname "$(readlink -f "$0")")"
echo "Running tests in Cyclecloud Marketplace container..."
docker run --platform linux/amd64 --rm -e OS_IMAGE_RESOURCE_ID="${OS_IMAGE_RESOURCE_ID}" "${CONTAINER_IMAGE}" /opt/cycle/cyclecloud-marketplace-image/test_cc_image.sh "${OS_IMAGE_RESOURCE_ID}"