#!/bin/bash
set -e

# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="australia-southeast1"
REPO_NAME="neuropilot"
SERVICE_ACCOUNT_NAME="github-actions-deployer"
POOL_NAME="github-actions-pool"
PROVIDER_NAME="github-actions-provider"
GITHUB_REPO="BishalBudhathoki/alterred" # Adjust if needed

echo "Setting up GCP for project: $PROJECT_ID in region: $REGION"

# 1. Enable APIs
echo "Enabling required APIs..."
gcloud services enable \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com

# 2. Create Artifact Registry
echo "Creating Artifact Registry repository..."
if ! gcloud artifacts repositories describe $REPO_NAME --location=$REGION &>/dev/null; then
  gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker \
    --location=$REGION \
    --description="Docker repository for Neuropilot"
else
  echo "Repository $REPO_NAME already exists."
fi

# 3. Create Service Account
echo "Creating Service Account..."
if ! gcloud iam service-accounts describe $SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com &>/dev/null; then
  gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name="GitHub Actions Deployer"
else
  echo "Service Account $SERVICE_ACCOUNT_NAME already exists."
fi

echo "Waiting for Service Account propagation..."
sleep 15

SA_EMAIL="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# 4. Grant Roles
echo "Granting IAM roles..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/run.admin"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountUser"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/artifactregistry.writer"

# 5. Workload Identity Federation
echo "Setting up Workload Identity Federation..."
if ! gcloud iam workload-identity-pools describe $POOL_NAME --location="global" &>/dev/null; then
  gcloud iam workload-identity-pools create $POOL_NAME \
    --location="global" \
    --display-name="GitHub Actions Pool"
else
  echo "Pool $POOL_NAME already exists."
fi

POOL_ID=$(gcloud iam workload-identity-pools describe $POOL_NAME --location="global" --format="value(name)")

if ! gcloud iam workload-identity-pools providers describe $PROVIDER_NAME --location="global" --workload-identity-pool=$POOL_NAME &>/dev/null; then
  gcloud iam workload-identity-pools providers create-oidc $PROVIDER_NAME \
    --location="global" \
    --workload-identity-pool=$POOL_NAME \
    --display-name="GitHub Actions Provider" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository=='$GITHUB_REPO'" \
    --issuer-uri="https://token.actions.githubusercontent.com"
else
  echo "Provider $PROVIDER_NAME already exists."
fi

echo "Waiting for WIF Provider propagation..."
sleep 15

PROVIDER_ID=$(gcloud iam workload-identity-pools providers describe $PROVIDER_NAME --location="global" --workload-identity-pool=$POOL_NAME --format="value(name)")

# 6. Bind Service Account to WIF
echo "Binding Service Account to WIF..."
gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/$POOL_ID/attribute.repository/$GITHUB_REPO"

echo "--------------------------------------------------"
echo "Setup Complete!"
echo "--------------------------------------------------"
echo "Add the following to your GitHub Repository Secrets/Variables:"
echo ""
echo "Secrets:"
echo "  (None strictly required for Backend if using WIF, but Frontend needs Firebase)"
echo ""
echo "Variables:"
echo "  GCP_PROJECT_ID: $PROJECT_ID"
echo "  REGION: $REGION"
echo "  GAR_LOCATION: $REGION"
echo "  ARTIFACT_REPO: $REPO_NAME"
echo "  WIF_PROVIDER: $PROVIDER_ID"
echo "  WIF_SERVICE_ACCOUNT: $SA_EMAIL"
echo ""
echo "For Firebase Hosting (Frontend):"
echo "Run: firebase init hosting:github"
