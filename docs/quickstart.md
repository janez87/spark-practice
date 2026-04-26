# Quick start (students)

## Prerequisites

- Docker Desktop (Mac / Windows) **or** Docker Engine + Compose v2 plugin (Linux).
- `make` — pre-installed on macOS and most Linux distros; on Windows use WSL.
- ~6 GB disk for the first image pull, ~4 GB RAM available to Docker.

Check your install:
```bash
docker --version          # Docker version 24+ recommended
docker compose version    # v2.20+
```

## First run

```bash
git clone https://github.com/janez87/spark-practice.git
cd spark-practice
make init      # creates .env from .env.example — edit if you want
make up        # pulls images from Docker Hub, then starts everything
```

You should see:

```
JupyterLab → http://localhost:8888
Spark UI   → http://localhost:8080
```

Open the JupyterLab URL in a browser. Your notebooks live under `notebooks/` on your host — anything you save in JupyterLab persists there.

## Daily workflow

```bash
make up               # bring everything up
make logs             # tail JupyterLab logs (Ctrl-C to stop tailing)
make logs SERVICE=spark-master
make down             # stop the cluster (volumes preserved)
```

To wipe everything (including stored Spark history events):
```bash
make clean
```

## Datasets

The notebooks expect their datasets under `notebooks/data/`. Run:

```bash
make fetch-data
```

If your instructor has shared a different URL, set `DATA_URL`:

```bash
DATA_URL=https://example.com/spark-practice-data.zip make fetch-data
```

## Adding workers

By default the stack runs **2 workers**. Change it in `.env`:

```
WORKERS=4
SPARK_WORKER_CORES=2
SPARK_WORKER_MEMORY=2G
```

then `make up` again. Each replica gets its own worker UI; check the master at http://localhost:8080 to see them register.

## Kafka / HDFS overlays

```bash
make up-kafka      # adds zookeeper, kafka, schema-registry
make up-hdfs       # adds namenode, datanode
```

Stop them the usual way: `make down` (or `make clean`).

Kafka bootstrap server inside the cluster: `kafka:29092`. From your host (e.g. for `kcat`): `localhost:9092`.

## Stopping individual services

```bash
docker compose -f compose/docker-compose.yml stop spark-worker
```

## Where to go next

- [`docs/troubleshooting.md`](troubleshooting.md) — common problems.
- [`docs/upgrading.md`](upgrading.md) — what changed if you used the old stack.
- [`docs/build-from-source.md`](build-from-source.md) — for maintainers and contributors.
