#!/bin/sh

set -eu

RESPONSE=$(curl -w "${response_code}" -L -o "/var/www/build.zip" \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer <YOUR-TOKEN>" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/angelajfisher/static-deployment-test/actions/artifacts/$ARTIFACT_ID/zip")

if [ "$RESPONSE" != "200" ]; then
  echo "ERROR - SHUTTING DOWN: Code $RESPONSE received from curl request. Parity cannot be acheived, so the server is shutting down."

  systemctl stop apache2

  exit 1
fi

systemctl stop apache2 || true

rm -r -- * || true

unzip -o "/var/www/build.zip"

systemctl start apache2

rm "/var/www/build.zip"
