#!/bin/bash
# Upload a screenshot to Cloudinary and return the URL
# Usage: upload-cloudinary.sh <image-path> [tag]
# Requires cloudinary.json or CLOUDINARY_* env vars

IMAGE_PATH="$1"
TAG="${2:-wp-eb-test}"

if [ ! -f "$IMAGE_PATH" ]; then
  echo "ERROR: Image not found at $IMAGE_PATH" >&2
  exit 1
fi

# Try to read credentials from cloudinary.json in current dir or plugin dir
CLOUD_NAME=""
UPLOAD_PRESET=""
API_KEY=""
API_SECRET=""

for CONFIG in "./cloudinary.json" "../cloudinary.json" "$HOME/.cloudinary.json"; do
  if [ -f "$CONFIG" ]; then
    CLOUD_NAME=$(grep -o '"cloud_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG" | sed 's/.*"\([^"]*\)"$/\1/')
    UPLOAD_PRESET=$(grep -o '"upload_preset"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG" | sed 's/.*"\([^"]*\)"$/\1/')
    API_KEY=$(grep -o '"api_key"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG" | sed 's/.*"\([^"]*\)"$/\1/')
    API_SECRET=$(grep -o '"api_secret"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG" | sed 's/.*"\([^"]*\)"$/\1/')
    break
  fi
done

# Fall back to env vars
CLOUD_NAME="${CLOUD_NAME:-$CLOUDINARY_CLOUD_NAME}"
UPLOAD_PRESET="${UPLOAD_PRESET:-$CLOUDINARY_UPLOAD_PRESET}"
API_KEY="${API_KEY:-$CLOUDINARY_API_KEY}"
API_SECRET="${API_SECRET:-$CLOUDINARY_API_SECRET}"

if [ -z "$CLOUD_NAME" ]; then
  echo "ERROR: No Cloudinary cloud_name found. Create cloudinary.json or set CLOUDINARY_CLOUD_NAME" >&2
  exit 2
fi

UPLOAD_URL="https://api.cloudinary.com/v1_1/$CLOUD_NAME/image/upload"

# Unsigned upload (preferred, simpler)
if [ -n "$UPLOAD_PRESET" ]; then
  RESPONSE=$(curl -s -X POST "$UPLOAD_URL" \
    -F "file=@$IMAGE_PATH" \
    -F "upload_preset=$UPLOAD_PRESET" \
    -F "tags=$TAG")
# Signed upload (fallback, needs API key + secret)
elif [ -n "$API_KEY" ] && [ -n "$API_SECRET" ]; then
  TIMESTAMP=$(date +%s)
  SIGNATURE=$(echo -n "tags=$TAG&timestamp=$TIMESTAMP$API_SECRET" | shasum -a 1 | awk '{print $1}')
  RESPONSE=$(curl -s -X POST "$UPLOAD_URL" \
    -F "file=@$IMAGE_PATH" \
    -F "api_key=$API_KEY" \
    -F "timestamp=$TIMESTAMP" \
    -F "signature=$SIGNATURE" \
    -F "tags=$TAG")
else
  echo "ERROR: Need either upload_preset (unsigned) or api_key+api_secret (signed)" >&2
  exit 3
fi

# Extract secure_url from JSON response
URL=$(echo "$RESPONSE" | grep -o '"secure_url"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')

if [ -z "$URL" ]; then
  echo "ERROR: Upload failed. Response: $RESPONSE" >&2
  exit 4
fi

echo "$URL"
exit 0
