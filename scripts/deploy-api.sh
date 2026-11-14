#!/usr/bin/env bash
# Builds the API and embedding images on this machine, loads them onto the
# EC2 server and (re)starts the stack there.
#
#   scripts/deploy-api.sh
#
# Needs: Docker running locally, server/.env.prod (see server/.env.example),
# and the app repos as siblings of this repo (../cognify-ops-api,
# ../embedding-microservice).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APPS="$(cd "$REPO/.." && pwd)"
ENV_FILE="$REPO/server/.env.prod"

[[ -f "$ENV_FILE" ]] || { echo "Missing server/.env.prod (copy server/.env.example)"; exit 1; }

HOST="$(terraform -chdir="$REPO" output -raw server_public_ip)"
QUEUE_URL="$(terraform -chdir="$REPO" output -raw sqs_queue_url)"
REMOTE="ubuntu@${HOST}"
SSH=(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

echo "==> Building images for linux/arm64"
docker build --platform linux/arm64 -t cognify-api:latest "$APPS/cognify-ops-api"
docker build --platform linux/arm64 -t cognify-embedding:latest "$APPS/embedding-microservice"

echo "==> Waiting for the server's first-boot setup to finish"
"${SSH[@]}" "$REMOTE" "cloud-init status --wait >/dev/null; docker --version"

echo "==> Loading images onto $HOST"
docker save cognify-api:latest cognify-embedding:latest | gzip | "${SSH[@]}" "$REMOTE" "gunzip | docker load"

echo "==> Copying the Compose file and environment"
scp -o StrictHostKeyChecking=accept-new "$REPO/server/docker-compose.yml" "$REMOTE:/opt/cognify/docker-compose.yml"
{
  cat "$ENV_FILE"
  echo "AWS_REGION=ap-southeast-2"
  echo "SQS_QUEUE_URL=$QUEUE_URL"
} | "${SSH[@]}" "$REMOTE" "umask 077 && cat > /opt/cognify/.env"

echo "==> Starting the stack"
"${SSH[@]}" "$REMOTE" "cd /opt/cognify && docker compose up -d --remove-orphans && docker image prune -f >/dev/null && docker compose ps"

echo "==> Health check"
for _ in $(seq 1 30); do
  if curl -fsS -m 5 "http://$HOST/api/health"; then echo; echo "Deployed: http://$HOST/api"; exit 0; fi
  sleep 3
done
echo "The API did not answer on http://$HOST/api/health"
"${SSH[@]}" "$REMOTE" "cd /opt/cognify && docker compose logs --tail 40 api"
exit 1
