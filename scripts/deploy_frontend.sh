#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID="${PROJECT_ID:-neuropilot-23fb5}"
cd frontend/flutter_neuropilot
if [ -z "${FIREBASE_API_KEY:-}" ] || [ -z "${FIREBASE_APP_ID:-}" ] || [ -z "${FIREBASE_MESSAGING_SENDER_ID:-}" ] || [ -z "${FIREBASE_PROJECT_ID:-}" ]; then
  echo "Missing Firebase web env"
  exit 1
fi
flutter pub get
flutter build web --release -t lib/main.dart \
  --dart-define=API_BASE_URL=/api \
  --dart-define=FIREBASE_API_KEY="${FIREBASE_API_KEY}" \
  --dart-define=FIREBASE_APP_ID="${FIREBASE_APP_ID}" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID}" \
  --dart-define=FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID}"
cd ../../
firebase use "${PROJECT_ID}"
firebase deploy --only hosting --project "${PROJECT_ID}"

