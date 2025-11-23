#!/usr/bin/env bash
set -euo pipefail
export PROJECT_ID="${PROJECT_ID:-neuropilot-23fb5}"
export REGION="${REGION:-australia-southeast1}"
./scripts/deploy_backend.sh
./scripts/deploy_frontend.sh
./scripts/deploy_functions.sh || true

