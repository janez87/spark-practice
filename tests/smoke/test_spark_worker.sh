#!/usr/bin/env bash
# Verifies at least one worker container reports healthy via Compose.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}/compose"

worker="$(docker compose ps --status running --format '{{.Name}}' spark-worker | head -n1)"
if [[ -z "${worker}" ]]; then
    echo "No running spark-worker container found" >&2
    exit 1
fi

echo "Found running worker: ${worker}"
docker exec "${worker}" curl -fsS http://localhost:8081/ >/dev/null
echo "Worker UI reachable inside container ${worker}"
