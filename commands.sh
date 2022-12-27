# TCP local tunnel
gcloud alpha workstations start-tcp-tunnel --region $GCP_REGION --cluster $WORKSTATIONS_CLUSTER_NAME --config $WORKSTATIONS_CONFIG_NAME $WORKSTATIONS_WORKSTATION_NAME 9876

# Specifying local port
gcloud alpha workstations start-tcp-tunnel --region $GCP_REGION --cluster $WORKSTATIONS_CLUSTER_NAME --config $WORKSTATIONS_CONFIG_NAME $WORKSTATIONS_WORKSTATION_NAME 9876 --local-host-port=localhost:62339

# Creds for remote k8s cluster
gcloud container clusters get-credentials --region $GCP_REGION microservices

# Skaffold local dev
kubectl config use-context minikube
skaffold dev

# Skaffold build
skaffold build --file-output=/tmp/build.json
skaffold build --file-output=/tmp/build.json --default-repo=$GCP_REGION-docker.pkg.dev/$GCP_PROJECT_ID/microservices --push

# Skaffold rendering
skaffold render --build-artifacts=/tmp/build.json
skaffold render --build-artifacts=/tmp/build.json --profile=staging

# Run CD
gcloud deploy releases create rel-$(date +%d%m%y%H%M%S) \
  --project=$GCP_PROJECT_ID \
  --region=$GCP_REGION \
  --delivery-pipeline=my-run-demo-app-1 \
  --images=my-app-image=gcr.io/cloudrun/hello
