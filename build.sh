#!/bin/bash
# Build script for Augmentoolkit Docker container

set -e

echo "=========================================="
echo "Augmentoolkit Container Build Script"
echo "=========================================="

# Configuration
IMAGE_NAME="augmentoolkit"
IMAGE_TAG="${1:-latest}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

echo "Building Docker image: ${FULL_IMAGE_NAME}"
echo ""

# Build the Docker image
docker build -t "${FULL_IMAGE_NAME}" .

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Build successful!"
    echo "Image: ${FULL_IMAGE_NAME}"
    echo ""
    echo "Next steps:"
    echo "1. Test the container locally (if you have GPU):"
    echo "   docker run --gpus all -v \$(pwd)/test_data:/data ${FULL_IMAGE_NAME} --help"
    echo ""
    echo "2. Save the image for transfer to cluster:"
    echo "   docker save ${FULL_IMAGE_NAME} | gzip > ${IMAGE_NAME}.tar.gz"
    echo ""
    echo "3. Transfer to cluster and convert to Apptainer:"
    echo "   apptainer build ${IMAGE_NAME}.sif docker-archive://${IMAGE_NAME}.tar.gz"
    echo ""
    echo "4. Or push to Docker Hub and build on cluster:"
    echo "   docker tag ${FULL_IMAGE_NAME} yourusername/${FULL_IMAGE_NAME}"
    echo "   docker push yourusername/${FULL_IMAGE_NAME}"
    echo "   apptainer build ${IMAGE_NAME}.sif docker://yourusername/${FULL_IMAGE_NAME}"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "Build failed!"
    echo "Check the error messages above"
    echo "=========================================="
    exit 1
fi
