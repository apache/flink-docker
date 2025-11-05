#!/usr/bin/env bash

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This script copies Flink docker images from GHCR to Docker Hub.
# It uses crane to efficiently copy images without pulling them locally.
#
# Prerequisites:
#   - crane installed (https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane.md)
#   - Authentication to Docker Hub (docker login)
#
# Usage:
#   ./publish-to-dockerhub.sh [--dry-run]
#   SOURCE_REGISTRY=ghcr.io/myorg/flink-docker TARGET_REGISTRY=myorg/flink ./publish-to-dockerhub.sh
#   ./publish-to-dockerhub.sh --dry-run  # Test without actually copying

set -euo pipefail

# Parse command line arguments
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -n    Show what would be copied without actually copying"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  SOURCE_REGISTRY  Source registry (default: ghcr.io/apache/flink-docker)"
            echo "  TARGET_REGISTRY  Target registry (default: apache/flink)"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

source common.sh

# Configuration
SOURCE_REGISTRY=${SOURCE_REGISTRY:-"ghcr.io/apache/flink-docker"}
TARGET_REGISTRY=${TARGET_REGISTRY:-"apache/flink"}

echo "============================================"
echo "Publishing Flink Docker Images"
if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN MODE - No images will be copied"
fi
echo "============================================"
echo "Source: $SOURCE_REGISTRY"
echo "Target: $TARGET_REGISTRY"
echo "============================================"
echo ""

# Confirmation check
if [ "$DRY_RUN" = false ]; then
    echo "⚠️  IMPORTANT: Before running this script, ensure that:"
    echo ""
    echo "1. The GitHub Actions workflow 'Build and Push Docker Images' has"
    echo "   completed successfully for the release you want to publish"
    echo ""
    echo "2. All Docker images are available in GHCR at:"
    echo "   https://github.com/orgs/apache/packages?repo_name=flink-docker"
    echo "   (or https://github.com/users/${USER}/packages if using a fork)"
    echo ""
    echo "3. The images were built from the correct branch/tag"
    echo "   - For releases: master branch"
    echo "   - For testing: dev-* branches"
    echo ""
    echo "4. You are authenticated to Docker Hub:"
    echo "   docker login"
    echo ""
    read -p "Have you verified the above? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "❌ Aborted. Please verify the build workflow completed successfully first."
        exit 1
    fi

    echo "✅ Proceeding with image publication..."
    echo ""
else
    echo "🔍 Dry-run mode: Will verify images exist and show what would be copied"
    echo ""
fi

# Check if crane is installed
if ! command -v crane &> /dev/null; then
    echo "ERROR: crane is not installed"
    echo "Please install crane from: https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane.md"
    echo ""
    echo "Quick install:"
    echo "  macOS:   brew install crane"
    echo "  Linux:   go install github.com/google/go-containerregistry/cmd/crane@latest"
    exit 1
fi

# Process each Dockerfile
for dockerfile in $(find . -name "Dockerfile" | sort); do
    dir=$(dirname "$dockerfile")

    # Extract version and java version from Dockerfile
    FLINK_VERSION=$(grep "FLINK_TGZ_URL=" "$dockerfile" | head -1 | sed -E 's/.*flink-([0-9]+\.[0-9]+\.[0-9]+).*/\1/')

    # Extract java version from directory name (e.g., scala_2.12-java11-ubuntu -> java11)
    JAVA_VERSION=$(basename "$dir" | sed -E 's/.*-java([0-9]+)-.*/\1/')

    if [ -z "$FLINK_VERSION" ] || [ -z "$JAVA_VERSION" ]; then
        echo "⚠️  Skipping $dir - could not extract version info"
        continue
    fi

    # Construct source image tag
    SOURCE_TAG="${FLINK_VERSION}-scala_2.12-java${JAVA_VERSION}"
    SOURCE_IMAGE="${SOURCE_REGISTRY}:${SOURCE_TAG}"

    # Read target tags from metadata
    metadata="$dir/release.metadata"
    if [ ! -f "$metadata" ]; then
        echo "⚠️  Skipping $dir - no metadata file found"
        continue
    fi

    tags=$(extractValue "Tags" "$metadata")
    tags=$(pruneTags "$tags" "$latest_version")

    echo "📦 Processing Flink ${FLINK_VERSION} Java ${JAVA_VERSION}"
    echo "   Source: ${SOURCE_IMAGE}"

    # Check if source image exists
    if ! crane manifest "$SOURCE_IMAGE" &> /dev/null; then
        echo "   ❌ ERROR: Source image not found in GHCR"
        echo "   Please ensure the image was built and pushed by the CI workflow"
        echo ""
        echo "Aborting: Cannot proceed with missing images"
        exit 1
    fi

    # Copy to each target tag
    IFS=',' read -ra TAGS_ARRAY <<< "$tags"
    for raw_tag in "${TAGS_ARRAY[@]}"; do
        # Trim whitespace
        tag=$(echo "$raw_tag" | xargs)
        TARGET_IMAGE="${TARGET_REGISTRY}:${tag}"

        if [ "$DRY_RUN" = true ]; then
            echo "   🔍 Would copy to ${TARGET_IMAGE}"
        else
            echo "   📤 Copying to ${TARGET_IMAGE}"
            if crane copy "$SOURCE_IMAGE" "$TARGET_IMAGE"; then
                echo "      ✅ Success"
            else
                echo "      ❌ Failed"
                exit 1
            fi
        fi
    done

    echo ""
done

echo "============================================"
if [ "$DRY_RUN" = true ]; then
    echo "🔍 Dry-run completed successfully!"
    echo "Run without --dry-run to actually copy images."
else
    echo "✅ All images published successfully!"
fi
echo "============================================"
