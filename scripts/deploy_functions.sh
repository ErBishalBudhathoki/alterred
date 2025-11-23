#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID="${PROJECT_ID:-neuropilot-23fb5}"
gcloud config set project "${PROJECT_ID}"
gcloud services enable cloudfunctions.googleapis.com || true
cd functions
npm install --no-audit --no-fund
npm run build
cd ..
firebase use "${PROJECT_ID}"
firebase deploy --only functions --project "${PROJECT_ID}"

