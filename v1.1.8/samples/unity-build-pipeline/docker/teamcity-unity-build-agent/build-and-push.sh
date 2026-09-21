#!/bin/bash
set -e

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-unity-teamcity-agent}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Unity Editor version configuration (example values - update as needed)
# Find versions and changesets at: https://unity.com/releases/editor/archive
# Click on a version, the URL will contain the changeset (e.g., /6000.0.23f1/bd20d88e54b8)
#
# Set to empty string to skip Unity Editor installation (only Unity Hub will be installed)
# Example: UNITY_VERSION="" UNITY_CHANGESET="" ./build-and-push.sh
UNITY_VERSION="${UNITY_VERSION:-6000.0.23f1}"
UNITY_CHANGESET="${UNITY_CHANGESET:-bd20d88e54b8}"

# Full image name
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE_NAME="${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}:${IMAGE_TAG}"

echo "Building Unity + TeamCity agent image..."
echo "Registry: ${ECR_REGISTRY}"
echo "Repository: ${ECR_REPOSITORY_NAME}"
echo "Image Tag: ${IMAGE_TAG}"
echo ""
echo "Unity Hub: Latest stable (from official repository)"
if [ -n "${UNITY_VERSION}" ] && [ -n "${UNITY_CHANGESET}" ]; then
    echo "Unity Editor: ${UNITY_VERSION} (changeset: ${UNITY_CHANGESET})"
else
    echo "Unity Editor: Not installed (Hub only - install editors at runtime)"
fi
echo ""

# Check if ECR repository exists, create if it doesn't
if ! aws ecr describe-repositories --repository-names "${ECR_REPOSITORY_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "Creating ECR repository: ${ECR_REPOSITORY_NAME}"
    aws ecr create-repository \
        --repository-name "${ECR_REPOSITORY_NAME}" \
        --region "${AWS_REGION}" \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256
    echo ""
fi

# Login to ECR
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin "${ECR_REGISTRY}"
echo ""

# Build the Docker image for AMD64 platform (Fargate runs on x86_64)
echo "Building Docker image for linux/amd64 platform..."
echo "NOTE: This build takes 15-30 minutes due to Unity Editor installation"
docker build --platform linux/amd64 \
    --build-arg UNITY_VERSION="${UNITY_VERSION}" \
    --build-arg UNITY_CHANGESET="${UNITY_CHANGESET}" \
    -t "${ECR_REPOSITORY_NAME}:${IMAGE_TAG}" .
echo ""

# Tag for ECR
echo "Tagging image for ECR..."
docker tag "${ECR_REPOSITORY_NAME}:${IMAGE_TAG}" "${FULL_IMAGE_NAME}"
echo ""

# Push to ECR
echo "Pushing image to ECR..."
docker push "${FULL_IMAGE_NAME}"
echo ""

echo "✅ Successfully built and pushed image:"
echo "   ${FULL_IMAGE_NAME}"
echo ""
echo "To use this image, update your main.tf with:"
echo "   image = \"${FULL_IMAGE_NAME}\""
