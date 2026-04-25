#!/usr/bin/env bash
# Verifies the Spark master UI is responding and reports at least one worker.
set -euo pipefail

UI_URL="http://localhost:${SPARK_MASTER_UI_PORT:-8080}"

# Retry for ~60s while the cluster comes up.
for _ in $(seq 1 30); do
    if curl -fsS "${UI_URL}/" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

curl -fsS "${UI_URL}/" >/dev/null
echo "Spark master UI reachable at ${UI_URL}"

# JSON endpoint exposed by the master; count alive workers.
workers="$(curl -fsS "${UI_URL}/json/" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(sum(1 for w in d.get("workers", []) if w.get("state") == "ALIVE"))')"
echo "Alive workers: ${workers}"
[[ "${workers}" -ge 1 ]]
