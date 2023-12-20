#!/bin/sh

set -eu

curl -L -o "/var/www/build.zip" \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer <YOUR-TOKEN>" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/angelajfisher/static-deployment-test/actions/artifacts/$ARTIFACT_ID/zip"

rm -r -- * || true

unzip -o "/var/www/build.zip"

rm "/var/www/build.zip"

if "$NEEDS_PARITY"; then
curl -d "{\"data\": {\"artifact-id\": \"$ARTIFACT_ID\", \"needs-parity\": false}}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -k "https://<LOCAL IP>:9000/hooks/pull-site-changes"
fi
