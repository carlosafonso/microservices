# microservices

This repository contains a demo of a sample microservices-based architecture on top of Google Cloud Platform (GCP). The idea of this demo is to easily set up and play around with concepts such as CI/CD deployment techniques, service meshes, service discovery, operational dashboards, etc.

> **NOTE:** Older versions of this project used to support Amazon Web Services (AWS) too, but this is no longer the case. The latest commit that had functional AWS resources was 4873f90.

> **WARNING:** This documentation is currently WIP.

## Architecture

The current implementation deploys all services on two compute platforms: Google Kubernetes Engine (GKE) and Cloud Run. The Cloud Run section also publishes events to Pub/Sub, which are handled by the Worker service (also running on Cloud Run).

A CI/CD pipeline deploys the Frontend service to GKE environments when a developer pushes a new change.

The following diagram shows the overall architecture of this demo:

![Architecture diagram](architecture.png)

## How to deploy

All commands must be run from the `infra/` folder unless stated otherwise.

1. Clone this repo into your Cloud Shell instance.
2. Make sure that environment variable `GOOGLE_CLOUD_PROJECT` is defined.
3. Copy `terraform.tfvars.dist` into `terraform.tfvars`:

    ```
    cp terraform.tfvars.dist terraform.tfvars
    ```

4. Edit `terraform.tfvars` and set the apporpriate values.
5. Deploy the Terraform template:

    ```
    terraform apply -auto-approve
    ```

    > **NOTE:** The Terraform module will automatically enable the necessary Google Cloud APIs.

    > **NOTE:** If your project already has App Engine enabled, you might want to set `enable_app_engine` to `false` in your `terraformm.tfvars` file to avoid errors.

6. The Terraform template will use local provisioners to add your copy of the Git repository as a Git remote, and then hydrate some files with the appropriate values via a local provisioner. Commit whatever changes were produced and push them to Google Cloud Source Repositories.

    ```
    git add -f kubernetes/
    git commit -m "Add hydrated manifests" && git push -u google master
    ```

This will also trigger the delivery pipelines and create the first release.

### Deployment parameters

The Terraform template exposes several variables with default values that you can tweak. You can view them all in [`variables.tf`](infra/variables.tf), but in a nutshell these are:

* `gcp_project_id`: (**REQUIRED**) The ID of the GCP project where the template should be deployed.
* `gcp_region`: (**REQUIRED**) The GCP region where the template should be deployed.
* `enable_apis`: Whether to automatically enable the necessary Google Cloud APIs.
* `enable_app_engine`: Whether to automatically create and enable App Engine. If an App Engine application has already been defined, you should set this to `false`.
* `initial_words`: The initial set of words to store in the word service.
* `enable_load_generator`: Whether to deploy synthetic load against the production environment. If enabled, this can incur additional cost.

## Running the demos

Refer to the following docs to understand how to run the demos:

* [Autoscaling](docs/demo-autoscaling.md)
* [Tracing](docs/demo-tracing.md)

### About the load generator

If the `enable_load_generator` parmaeter is set to `true`, a Cloud Scheduler trigger will run periodically triggering a Cloud Rub job (see [src/load-generator](src/load-generator) for reference). This job uses the Locust load generation tool to send a varying amount of requests across a given period of time, which should help demonstrating GCP's autoscaling capabilities.

> **NOTE:** The load generation job currently only sends traffic to the Cloud Run stack. The GKE stack does not yet support load generation.
