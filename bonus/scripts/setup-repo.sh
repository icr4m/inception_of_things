#!/bin/sh
set -eu

echo ""

REPO=iot
HOST=gitlab-webservice-default.gitlab.svc.cluster.local:8080

until curl -s -o /dev/null $HOST/api/v4/version; do
  echo "Waiting for GitLab..."
  sleep 5
done

echo "password: $ROOT_PASSWORD"

TOKEN=$(curl -s -X POST \
  -d "login=root&password=$ROOT_PASSWORD" \
  http://$HOST/api/v4/session \
  | jq -r .private_token)

echo "token: $TOKEN"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --header "PRIVATE-TOKEN: $TOKEN" \
  http://$HOST/api/v4/projects/root%2F$REPO)

if [ "$STATUS" != "200" ]; then
  echo "Creating repo..."
  curl --request POST \
    --header "PRIVATE-TOKEN: $TOKEN" \
    --data "name=$REPO" \
    http://$HOST/api/v4/projects
fi
