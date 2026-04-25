# Upgrading from the previous lab stack

If you used the previous version of this repo (Spark 3.0.0, hand-rolled compose files, OSX-only Hub images), this is the migration list. None of the steps require code changes in the notebooks themselves; mostly file-path and command-name changes.

## At a glance

| Old                                                | New                                                       |
|----------------------------------------------------|-----------------------------------------------------------|
| `docker-compose.yml` at repo root                  | `compose/docker-compose.yml`                              |
| `docker-compose.kafka.yml`, `…hdfs.yml` at root    | `compose/compose.kafka.yml`, `compose.hdfs.yml` (profiles)|
| `docker compose up`                                | `make up`                                                 |
| `cd build && ./build.sh`                           | `make build`                                              |
| `janez87/spark-master` (untagged)                  | `janez87/spark-practice-spark-master:<tag>`               |
| `janez87/jupyterlab:3.0.0-spark-3.0.0`             | `janez87/spark-practice-jupyterlab:4.1.5-spark-3.5.1`     |
| Two named workers (`spark-worker-1/2`)             | One service `spark-worker` scaled via `WORKERS` env var   |
| Notebooks baked into the JupyterLab image          | Notebooks bind-mounted from `./notebooks/`                |
| `data.zip` LFS pointer                             | `make fetch-data` (URL configurable)                      |
| Builds amd64 only (slow on arm64)                  | Multi-arch (amd64 + arm64)                                |

## Breaking changes (in detail)

### 1. Image registry/tag scheme

All published images are now under `janez87/spark-practice-<name>` (note the `spark-practice-` prefix), tagged with the Spark version (e.g. `3.5.1`, plus a moving `latest`). Pin explicitly during the transition.

### 2. Spark 3.0.0 → 3.5.1

- Java 8 → Java 17 (Temurin).
- Hadoop 2.x → 3.
- Most PySpark / Scala API used in the PS0x notebooks is unchanged, but **manually run-all every notebook** before tagging the first release. A few RDD-API edge cases were removed in 3.4 / 3.5.

### 3. Compose file paths moved

Anything calling `docker compose -f docker-compose.yml ...` directly will break. The supported entry point is `make up`. If you had custom scripts, update the path:

```bash
# old
docker compose -f docker-compose.yml up

# new
docker compose -f compose/docker-compose.yml up
# or simply
make up
```

### 4. Workers no longer numbered

`spark-worker-1` and `spark-worker-2` collapsed into a single `spark-worker` service. Anything addressing them by container name now goes through Compose:

```bash
# old
docker exec spark-worker-1 bash

# new
docker compose -f compose/docker-compose.yml exec --index 1 spark-worker bash
```

Set `WORKERS=N` in `.env` to scale.

### 5. Notebooks no longer baked into the image

The "pull-only, no clone" path no longer ships notebooks. Students must `git clone` (or download a release tarball that includes `notebooks/`). The bind-mount means edits persist to the host — a feature, not a regression.

### 6. `data.zip` removed

Replaced by `make fetch-data`. The script has a `TODO` for the canonical dataset URL — set `DATA_URL` or edit `scripts/fetch-data.sh`.

### 7. Kafka stack rewritten

- One broker by default (was two with broken matching hostnames).
- Bootstrap inside the cluster: `kafka:29092` (was `kafka1:9092` / `kafka2:9093`).
- ksqlDB and `cnfltraining/training-tools` removed. Reintroduce behind a new profile if needed.
- Activated via `make up-kafka` (Compose profile `kafka`).

### 8. `hadoop.env` moved + slimmed

`hadoop.env` → `config/hadoop.env`, with YARN memory dropped from 16 GB to 2 GB. Override in `.env` if you need more.

### 9. `.env` semantics changed

The repo no longer ships a checked-in `.env`. Run `make init` (copies `.env.example`). Existing forks should:

```bash
git rm --cached .env
make init
```

### 10. Multi-arch images replace OSX-only images

First `docker pull` after the cut-over re-downloads layers (no shared blobs with old amd64-only images). Allow ~2 GB / student of bandwidth on the first lab session post-migration. After that, native-arch performance: notably faster on Apple Silicon and Linux arm64.

### 11. CI requires Docker Hub secrets

Before tagging the first release, configure repository secrets:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN` (read-write scoped to `janez87/spark-practice-*`)

Otherwise `build-and-push.yml` will fail and no images will publish.
