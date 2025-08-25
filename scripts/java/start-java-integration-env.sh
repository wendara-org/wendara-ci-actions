#!/bin/bash
set -euo pipefail
echo "▶ Starting integration test environment..."

COMPOSE_FILE="${COMPOSE_FILE:-code/src/test/resources/compose/docker-compose.yml}"
SERVICE_NAME="local-mongo"
[[ -f "$COMPOSE_FILE" ]] || { echo "❌ Not found: '$COMPOSE_FILE'"; exit 1; }

docker compose -f "$COMPOSE_FILE" up -d

echo "⏳ Waiting for health on service '$SERVICE_NAME'..."
CID="$(docker compose -f "$COMPOSE_FILE" ps -q "$SERVICE_NAME" || true)"
if [[ -z "$CID" ]]; then
  echo "❌ Service '$SERVICE_NAME' not found in compose."; docker compose -f "$COMPOSE_FILE" ps; exit 1
fi

for i in {1..40}; do
  status="$(docker inspect -f '{{.State.Health.Status}}' "$CID" 2>/dev/null || echo "starting")"
  [[ "$status" == "healthy" ]] && break
  sleep 3
done

status="$(docker inspect -f '{{.State.Health.Status}}' "$CID" 2>/dev/null || echo "unknown")"
if [[ "$status" != "healthy" ]]; then
  echo "❌ Service not healthy (status=$status). Recent logs:"
  docker logs --tail=200 "$CID" || true
  docker compose -f "$COMPOSE_FILE" ps
  exit 1
fi

docker compose -f "$COMPOSE_FILE" ps
echo "✅ Environment ready."
