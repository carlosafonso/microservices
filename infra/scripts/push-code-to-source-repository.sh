#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Please specify the URL of the Cloud Source Repository"
    exit 1
fi

REPO_URL=$1

# Add the Cloud Source Repositories credential helper so we are able to push.
git config --global credential.https://source.developers.google.com.helper gcloud.sh

# Add the CSR remote (remove it first if it exists already).
git remote remove google
git remote add google "$REPO_URL"

# Push to CSR.
git push google master
