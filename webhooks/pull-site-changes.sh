#!/bin/sh

set -eu

RESPONSE=$(curl -w "%{http_code}" -L -o "/var/www/build.zip" \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer <YOUR-TOKEN>" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/<NAMESPACE>/<REPOSITORY>/actions/artifacts/$ARTIFACT_ID/zip")

if [ "$RESPONSE" != "200" ]; then
  echo "ABORTING: Code $RESPONSE received from curl request."
  exit 1
fi

systemctl stop apache2

rm -r -- * || true

unzip -o "/var/www/build.zip"

systemctl start apache2

rm "/var/www/build.zip"

curl -d "{\"data\": {\"artifact-id\": \"$ARTIFACT_ID\"}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -k "https://<LOCAL IP>:9000/hooks/reach-parity"
