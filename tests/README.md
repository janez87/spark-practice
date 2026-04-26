# Smoke tests

Each `tests/smoke/test_*.sh` is a single-purpose, fail-fast check against a
running stack. They are aggregated by `scripts/smoke-test.sh` (also exposed
as `make smoke`).

Tests assume the Compose stack is already up via `make up` (and `make up-kafka`
for the Kafka overlay test).

| Test                       | Checks                                                 |
|----------------------------|--------------------------------------------------------|
| `test_spark_master.sh`     | Master UI reachable; at least one ALIVE worker         |
| `test_spark_worker.sh`     | At least one worker container running and serving 8081 |
| `test_jupyterlab.sh`       | JupyterLab `/api` reachable; `import pyspark` works    |
| `test_kafka_overlay.sh`    | Produce + consume on an ephemeral topic (kafka profile)|

Add new tests by dropping `test_<name>.sh` into this directory — the runner
picks them up automatically.
