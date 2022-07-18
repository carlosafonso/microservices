#!/usr/bin/bash
for image_name in "frontend" "font-color" "font-size" "word" "worker"; do
    docker pull "carlosafonso/microservices-$image_name"
    docker tag "carlosafonso/microservices-$image_name:latest" "gcr.io/$GOOGLE_CLOUD_PROJECT/microservices-$image_name:latest"
    docker push "gcr.io/$GOOGLE_CLOUD_PROJECT/microservices-$image_name:latest"
done