#!/bin/sh

set -eu

if [ "$ATTEMPT" -gt 1 ]; then
  echo "ABORTING: Loop detected."
  exit 1
fi

RESPONSE=$(curl -w "${response_code}" -L -o "/var/www/build.zip" \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer <YOUR-TOKEN>" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/angelajfisher/static-deployment-test/actions/artifacts/$ARTIFACT_ID/zip")

if [ "$RESPONSE" != "200" ]; then
  echo "ABORTING: Code $RESPONSE received from curl request."
  exit 1
fi

rm -r -- * || true

unzip -o "/var/www/build.zip"

rm "/var/www/build.zip"

if [ "$NEEDS_PARITY" = "true" ]; then
  ATTEMPT=$(( ATTEMPT + 1 ))
  curl -d "{\"data\": {\"artifact-id\": \"$ARTIFACT_ID\", \"needs-parity\": false, \"attempt\": \"$ATTEMPT\"}}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -k "https://<LOCAL IP>:9000/hooks/pull-site-changes"
fi
