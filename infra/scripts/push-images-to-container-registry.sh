#!/bin/bash

set -euo pipefail

print_usage () {
    cat << EOF

Usage:

    $0 [GCP_PROJECT_ID] [GCP_REGION]
EOF
}

if [ $# -lt 2 ]; then
    print_usage
    exit 1
fi

GOOGLE_CLOUD_PROJECT=$1
REGION=$2

gcloud auth configure-docker $REGION-docker.pkg.dev

for image_name in "frontend" "font-color" "font-size" "word" "worker"; do
    docker pull "carlosafonso/microservices-$image_name"
    docker tag "carlosafonso/microservices-$image_name:latest" "$REGION-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/microservices/microservices-$image_name:latest"
    docker push "$REGION-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/microservices/microservices-$image_name:latest"
done
