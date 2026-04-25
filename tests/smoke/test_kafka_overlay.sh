#!/usr/bin/env bash
# Verifies the kafka profile is up: produce + consume on a throwaway topic.
# Skipped silently if the kafka container is not running.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}/compose"

if ! docker compose ps --status running --format '{{.Name}}' kafka | grep -q .; then
    echo "kafka container not running — skipping kafka overlay smoke test"
    exit 0
fi

TOPIC="smoke-$(date +%s)"
docker compose exec -T kafka kafka-topics --bootstrap-server localhost:29092 \
    --create --topic "${TOPIC}" --partitions 1 --replication-factor 1

echo "hello-from-smoke-test" | docker compose exec -T kafka \
    kafka-console-producer --bootstrap-server localhost:29092 --topic "${TOPIC}"

msg="$(docker compose exec -T kafka kafka-console-consumer \
    --bootstrap-server localhost:29092 --topic "${TOPIC}" \
    --from-beginning --max-messages 1 --timeout-ms 10000)"

docker compose exec -T kafka kafka-topics --bootstrap-server localhost:29092 \
    --delete --topic "${TOPIC}" || true

[[ "${msg}" == "hello-from-smoke-test" ]]
echo "Kafka produce + consume round-trip succeeded"
