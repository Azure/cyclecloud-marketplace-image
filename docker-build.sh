  #! /bin/bash
  CONTAINER_IMAGE="cc_marketplace_image_builder"
  BUILD_DIR="$(dirname "$(readlink -f "$0")")"

  echo "Installing dependencies in Cyclecloud Marketplace container..."
  docker buildx build --file "Dockerfile.Ubuntu" --tag "${CONTAINER_IMAGE}" . --target install_deps
  
  echo "Building Cyclecloud Marketplace image in container..."
  docker run --rm -v "$BUILD_DIR/logs":"/opt/cycle/cyclecloud-marketplace-image/logs" "${CONTAINER_IMAGE}" /opt/cycle/cyclecloud-marketplace-image/build_image.sh