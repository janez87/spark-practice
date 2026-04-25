#!/usr/bin/env bash
# Verifies at least one worker container is reachable on its UI port.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}/compose"

worker_id="$(docker compose ps -q spark-worker | head -n1)"
if [[ -z "${worker_id}" ]]; then
    echo "No running spark-worker container found" >&2
    exit 1
fi

echo "Found running worker: ${worker_id}"
docker exec "${worker_id}" curl -fsS http://localhost:8081/ >/dev/null
echo "Worker UI reachable inside container ${worker_id}"
