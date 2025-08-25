#!/bin/bash
set -euo pipefail

echo "🧹 Stopping integration test environment..."

COMPOSE_FILE="code/src/test/resources/compose/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "⚠️ Docker Compose file not found. Nothing to stop."
  exit 0
fi

docker compose -f "$COMPOSE_FILE" down

echo "✅ Docker Compose environment stopped."
