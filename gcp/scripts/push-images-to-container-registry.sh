#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Please specify the GCP region where the Artifact Registry repository is located (e.g., us-central1)"
    exit 1
fi

REGION=$1

for image_name in "frontend" "font-color" "font-size" "word" "worker"; do
    docker pull "carlosafonso/microservices-$image_name"
    docker tag "carlosafonso/microservices-$image_name:latest" "$REGION-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/microservices/microservices-$image_name:latest"
    docker push "$REGION-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/microservices/microservices-$image_name:latest"
done
