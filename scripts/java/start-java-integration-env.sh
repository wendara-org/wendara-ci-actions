#!/bin/bash
set -euo pipefail
echo "▶ Starting integration test environment..."

COMPOSE_FILE="code/src/main/test/resources/compose/docker-compose.yml"
[[ -f "$COMPOSE_FILE" ]] || { echo "❌ Not found: $COMPOSE_FILE"; exit 1; }

docker compose -f "$COMPOSE_FILE" up -d

# Wait for health
for i in {1..40}; do
  status=$(docker inspect -f '{{.State.Health.Status}}' local-mongo 2>/dev/null || echo "starting")
  [[ "$status" == "healthy" ]] && break
  sleep 3
done

docker compose -f "$COMPOSE_FILE" ps
echo "✅ Environment ready."
