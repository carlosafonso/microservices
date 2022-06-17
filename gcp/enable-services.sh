#!/usr/bin/bash

# This script assumes that the project ID has already been set as the
# GOOGLE_CLOUD_PROJECT environment variable.

set -euxo pipefail

gcloud services enable compute.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable run.googleapis.com
