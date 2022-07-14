#!/usr/bin/bash
gcloud services enable \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    clouddeploy.googleapis.com \
    container.googleapis.com \
    sourcerepo.googleapis.com
