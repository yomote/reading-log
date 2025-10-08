#!/usr/bin/env bash
set -euo pipefail

# Usage (run from repository root):
#   ./terraform/scripts/push_ecr.sh <aws-region> <repository-uri> <image-tag> [<build-context>] [<dockerfile>]
# Example:
#   ./terraform/scripts/push_ecr.sh us-east-2 123456789012.dkr.ecr.us-east-2.amazonaws.com/reading-log-dev v1
#   ./terraform/scripts/push_ecr.sh us-east-2 123456789012.dkr.ecr.us-east-2.amazonaws.com/reading-log-dev v1 app app/Dockerfile

REGION=${1:?"AWS region is required"}
REPO_URI=${2:?"ECR repository URI is required"}
IMAGE_TAG=${3:?"Image tag is required"}

# Resolve paths relative to this script (located at terraform/scripts)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

# Optional build context and Dockerfile (defaults to repository root)
BUILD_CONTEXT_INPUT=${4:-"$REPO_ROOT"}
DOCKERFILE_INPUT=${5:-"$BUILD_CONTEXT_INPUT/Dockerfile"}

# Normalize paths if possible
BUILD_CONTEXT=$(realpath -m "$BUILD_CONTEXT_INPUT" 2>/dev/null || echo "$BUILD_CONTEXT_INPUT")
DOCKERFILE=$(realpath -m "$DOCKERFILE_INPUT" 2>/dev/null || echo "$DOCKERFILE_INPUT")

# Login to ECR
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${REPO_URI%/*}"

IMAGE_NAME="$REPO_URI:$IMAGE_TAG"

# Sanity check
if [ ! -f "$DOCKERFILE" ]; then
  echo "Dockerfile not found: $DOCKERFILE" >&2
  echo "Hint: pass build-context and dockerfile explicitly, e.g. 'app app/Dockerfile'" >&2
  exit 1
fi
if [ ! -d "$BUILD_CONTEXT" ]; then
  echo "Build context directory not found: $BUILD_CONTEXT" >&2
  exit 1
fi

echo "Building image: $IMAGE_NAME"
echo " - Build context: $BUILD_CONTEXT"
echo " - Dockerfile:    $DOCKERFILE"
docker build -t "$IMAGE_NAME" -f "$DOCKERFILE" "$BUILD_CONTEXT"

echo "Pushing image: $IMAGE_NAME"
docker push "$IMAGE_NAME"

echo "Done. Pushed $IMAGE_NAME"
