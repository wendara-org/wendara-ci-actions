#!/bin/bash
set -euo pipefail

echo "▶ Starting integration test environment..."

COMPOSE_FILE="code/src/main/test/resources/compose/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "❌ Docker Compose file not found at: '$COMPOSE_FILE'"
  exit 1
fi

docker-compose -f "$COMPOSE_FILE" up -d

echo "✅ Docker Compose environment started."
