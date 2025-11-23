#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID="${PROJECT_ID:-neuropilot-23fb5}"
REGION="${REGION:-australia-southeast1}"
SERVICE_NAME="${SERVICE_NAME:-neuropilot-api}"
IMAGE="gcr.io/${PROJECT_ID}/${SERVICE_NAME}:$(git rev-parse --short HEAD)"
gcloud config set project "${PROJECT_ID}"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com || true
gcloud builds submit --tag "${IMAGE}"
gcloud run deploy "${SERVICE_NAME}" --image "${IMAGE}" --region "${REGION}" --allow-unauthenticated --platform managed --set-env-vars FIREBASE_PROJECT_ID="${PROJECT_ID}"
URL=$(gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --format="value(status.url)")
echo "${URL}"

