# microservices/gcp

This folder contains an implementation of the microservices demo on top of Google Cloud Platform (GCP).

## Architecture

The current implementation deploys all services on Cloud Run. The Worker Service is push-subscribed to a Pub/Sub topic.

![Architecture diagram](architecture.png)

## How to deploy

(Note that this section is currently WIP.)

All commands must be run from the `gcp/` folder unless stated otherwise.

1. Clone this repo into your Cloud Shell instance.
2. Copy `terraform.tfvars.dist` into `terraform.tfvars`:

    ```
    cp terraform.tfvars.dist terraform.tfvars
    ```

3. Edit `terraform.tfvars` and set the apporpriate values.
4. Issue the following command to enable the required GCP APIs:

    ```
    ./scripts/enable-services.sh
    ```

5. Deploy the Terraform template:

    ```
    terraform apply -auto-approve
    ```
