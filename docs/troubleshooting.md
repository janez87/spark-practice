# Troubleshooting

## "Port already in use"

Default ports: `8888` (JupyterLab), `8080` (Spark master UI), `7077` (Spark master), `4040` (driver UI).

Override in `.env`:
```
JUPYTER_PORT=8899
SPARK_MASTER_UI_PORT=8090
```
then `make down && make up`.

## JupyterLab is "running" but the browser shows nothing

Check the actual healthcheck:
```bash
docker compose -f compose/docker-compose.yml ps jupyterlab
```
If `(unhealthy)`, look at logs:
```bash
make logs SERVICE=jupyterlab
```

## Spark workers don't register with the master

```bash
make logs SERVICE=spark-worker
```
Most common cause: the master container isn't actually healthy yet. Run `docker compose ps` and confirm `spark-master` is `(healthy)` before troubleshooting workers.

## "Slow on Apple Silicon / Linux arm64"

You may be pulling an amd64-only image (the old `andreper/*` images had this problem). Confirm the manifest:

```bash
docker manifest inspect janez87/spark-practice-spark-master:latest | grep -E 'architecture|os'
```

You should see both `amd64` and `arm64`. If you see only `amd64`, you're on an old tag — `docker pull janez87/spark-practice-spark-master:latest` to refresh.

## "I don't have enough RAM"

Defaults are tuned for an 8 GB laptop with Docker getting ~4 GB. Knobs in `.env`:

```
WORKERS=1
SPARK_WORKER_CORES=1
SPARK_WORKER_MEMORY=1G
SPARK_DRIVER_MEMORY=512m
SPARK_EXECUTOR_MEMORY=512m
```

For HDFS, `config/hadoop.env` is right-sized for laptops (2 GB NM, 2 vCore). If you need more, override in your `.env`.

## "Permission denied" on bind-mounted notebooks

The container runs as root by default. If your host enforces stricter ownership (some Linux distros + SELinux), add the `:Z` suffix to the bind mount in `compose/docker-compose.yml`:

```yaml
volumes:
  - ../notebooks:/opt/workspace:Z
```

## `make fetch-data` does nothing

The script has a TODO placeholder for the dataset URL. Either:
- Pass `DATA_URL=https://… make fetch-data`, or
- Edit `scripts/fetch-data.sh` and replace the placeholder.

Ask your instructor for the canonical URL if you don't have it.

## Wiping everything and starting fresh

```bash
make clean              # down + remove volumes
docker system prune -af # nuclear option: remove all unused images/networks
make pull
make up
```
