#!/usr/bin/env bash
set -euo pipefail

# Match the Flutter version used during local development.
FLUTTER_VERSION="3.47.1"

# These are public Flutter web configuration values,
# not Firebase Admin or Supabase service-role credentials.
: "${SUPABASE_URL:?Set SUPABASE_URL in Vercel environment variables.}"
: "${SUPABASE_PUBLISHABLE_KEY:?Set SUPABASE_PUBLISHABLE_KEY in Vercel environment variables.}"

echo "Preparing Flutter ${FLUTTER_VERSION}..."

FLUTTER_DIR="$(mktemp -d)/flutter"

git clone \
  --depth 1 \
  --branch "${FLUTTER_VERSION}" \
  https://github.com/flutter/flutter.git \
  "${FLUTTER_DIR}"

export PATH="${FLUTTER_DIR}/bin:${PATH}"
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true

flutter --version
flutter pub get

echo "Building Practicum Connect for web..."

flutter build web --release \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}" \
  --dart-define="SUPABASE_BUCKET=${SUPABASE_BUCKET:-internship-documents}"

if [ ! -f "build/web/index.html" ]; then
  echo "ERROR: Flutter web build output was not created." >&2
  exit 1
fi

echo "Flutter web build completed."
