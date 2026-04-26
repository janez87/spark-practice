# Changelog

All notable changes to this lab stack will be documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Multi-arch (`linux/amd64` + `linux/arm64`) image builds via `docker buildx`.
- `Makefile` as single entry point (`make up` / `make build` / `make push`).
- GitHub Actions: `ci.yml`, `build-and-push.yml`, `release.yml`.
- Compose **profiles** (`kafka`, `hdfs`) replacing the three top-level compose files.
- `HEALTHCHECK` directives on every image; `depends_on: condition: service_healthy` in Compose.
- Smoke-test suite under `tests/smoke/` with a runner at `scripts/smoke-test.sh`.
- `.dockerignore`, `.editorconfig`, `.env.example`.
- `CONTRIBUTING.md`, `CHANGELOG.md`, full `docs/` set (quickstart, build-from-source, troubleshooting, upgrading).
- `scripts/version.sh` + `.make/version.mk` as the single source of truth for image versions.

### Changed
- **Spark 3.0.0 → 3.5.1** (Java 17, Hadoop 3).
- Base image: `openjdk:8-jre-slim` → `eclipse-temurin:17-jre-jammy` (multi-arch, maintained).
- Image names: `janez87/<name>` → `janez87/spark-practice-<name>` with explicit Spark-version tags.
- `Spark home` moved to `/opt/spark` (was `/usr/bin/spark-…`).
- Spark master/worker `CMD`: shell-form with file-redirect → exec-form, logs to stdout.
- JupyterLab notebooks: baked into image → bind-mounted from host `./notebooks/`.
- Workers: two named services → one `spark-worker` scaled by `WORKERS` env var.
- `hadoop.env` moved to `config/hadoop.env`, YARN memory right-sized for laptops.
- `.gitignore` shrunk from 300+ lines (Spark project's template) to project-specific essentials.
- README rewritten for student audience.

### Removed
- Root `Dockerfile` (4-line `pip install shapely` patch — folded into `images/spark-worker/`).
- Root `docker-compose*.yml` (replaced by `compose/`).
- `build/build.sh`, `build/build.linux.sh`, `build/build.yml` (replaced by `Makefile`).
- `data.zip` (LFS pointer with no payload — replaced by `scripts/fetch-data.sh`).
- `pdfs/` (5.7 MB course slides — distribute out-of-band).
- `local/README.md` (replaced by `docs/quickstart.md`).
- Root `.env` with stale Confluent demo vars (replaced by `.env.example`).
- `.DS_Store` files.
- ksqlDB, `cnfltraining/training-tools`, second Kafka broker (broken upstream config).

### Fixed
- Kafka overlay: hostname collision (`kafka1` and `kafka2` both `hostname: kafka`).
- Kafka overlay: missing volume mounts (`$PWD/data`, `$PWD/scripts`, `$PWD/extensions`).
- Spark master/worker logs no longer disappear into a file inside the container.
- Image-tag drift between the three compose files (`janez87/<img>` vs `<img>:3.0.0`).
