#!/usr/bin/env bash
# Verifies the JupyterLab API is up and that pyspark can be imported.
set -euo pipefail

API_URL="http://localhost:${JUPYTER_PORT:-8888}/api"

for _ in $(seq 1 30); do
    if curl -fsS "${API_URL}" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done
curl -fsS "${API_URL}" >/dev/null
echo "JupyterLab API reachable at ${API_URL}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}/compose"
docker compose exec -T jupyterlab python3 -c "import pyspark; print('pyspark', pyspark.__version__)"
