#!/usr/bin/env bash
# Verifies the kafka profile is up: produce + consume on a throwaway topic.
# Skipped silently if the kafka container is not running.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}/compose"

# With the core compose file only, "kafka" isn't a defined service and the
# command errors out. Treat any failure (or empty output) as "skip".
kafka_id="$(docker compose ps -q kafka 2>/dev/null | head -n1 || true)"
if [[ -z "${kafka_id}" ]]; then
    echo "kafka container not running — skipping kafka overlay smoke test"
    exit 0
fi

TOPIC="smoke-$(date +%s)"
docker exec "${kafka_id}" kafka-topics --bootstrap-server localhost:29092 \
    --create --topic "${TOPIC}" --partitions 1 --replication-factor 1

echo "hello-from-smoke-test" | docker exec -i "${kafka_id}" \
    kafka-console-producer --bootstrap-server localhost:29092 --topic "${TOPIC}"

msg="$(docker exec "${kafka_id}" kafka-console-consumer \
    --bootstrap-server localhost:29092 --topic "${TOPIC}" \
    --from-beginning --max-messages 1 --timeout-ms 10000)"

docker exec "${kafka_id}" kafka-topics --bootstrap-server localhost:29092 \
    --delete --topic "${TOPIC}" || true

[[ "${msg}" == "hello-from-smoke-test" ]]
echo "Kafka produce + consume round-trip succeeded"
