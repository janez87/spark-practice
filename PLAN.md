# Refactor Plan — `spark-practice` Lab Stack

> Status: approved 2026-04-25. Execution branch: `refactor/lab-stack-v1`.
> See `CHANGES.md` for the as-built record once execution lands.

## 1. Audit Findings

### 1.1 Compose-file problems
- **Three overlapping compose files** (`docker-compose.yml`, `docker-compose.hdfs.yml`, `docker-compose.kafka.yml`) duplicate the `jupyterlab` / `spark-master` / `spark-worker-1/2` block verbatim. Maintaining four copies of the same worker block is the main source of drift.
- **Image-name inconsistency**: `docker-compose.yml` references `janez87/jupyterlab:3.0.0-spark-3.0.0` and `janez87/spark-master` (untagged, implicit `latest`), while `docker-compose.hdfs.yml` references the same images **without** the `janez87/` prefix (`spark-master:3.0.0`). Half the files target Docker Hub, half target a local build.
- **Mixed `image:` + `build:`**: `docker-compose.yml` has `spark-worker-1` / `spark-worker-2` declared with `build: .` (root `Dockerfile`), but the comment-out shows the original was `image:`. Students with no build context cannot start the cluster from Hub alone.
- **`docker-compose.kafka.yml` is broken**:
  - `kafka1` and `kafka2` both set `hostname: kafka` (collision; advertised listeners point to non-existent host).
  - Mounts `$PWD/data`, `$PWD/scripts`, `$PWD/extensions` that **do not exist** in the repo.
  - `${REPOSITORY}/ksqldb-server` has no tag → image-pull failure.
  - Pulls the **enterprise** Confluent image (`cp-enterprise-kafka`) — heavy + licensing baggage; community `cp-kafka` is enough for a class.
  - Includes `cnfltraining/training-tools:6.0` and `ksqldb-cli` not needed for the Spark Structured Streaming labs.
- **No healthchecks**, no `depends_on: condition: service_healthy`, no `restart` policy on the Spark services.
- **No Compose profiles** — students must remember which `-f` combinations are valid.
- Volume named `"hadoop-distributed-file-system"` even in the non-HDFS file; the name describes a use case, not the volume.
- `version: "3.6"` is obsolete (Compose v2 ignores it).

### 1.2 Dockerfile problems
- **Root `Dockerfile`** is a 4-line patch (`FROM spark-worker:3.0.0` + `pip3 install shapely`). It exists only to inject one library and forces students/CI to rebuild a child image. The dependency belongs in the worker image (or a `requirements.txt`) — not a parallel Dockerfile.
- **Layer caching is poor everywhere**: every Dockerfile does `apt-get update` immediately followed by package installs **after** an `ARG`, which invalidates the apt cache on every build-arg change. Curl + tar + rm of Spark/Scala in one big `RUN` is fine, but no use of `--mount=type=cache` for apt or pip.
- **`base/Dockerfile`** is built `FROM openjdk:8-jre-slim` — the `openjdk` image was deprecated by Docker Hub in 2022 and is **amd64-only for many tags**. This is the root cause of the "Hub images are slow on non-OSX" complaint: the published images are amd64 binaries running under QEMU on Apple Silicon and Linux/arm64 hosts.
- **`base/Dockerfile`** downloads Scala via `curl` from `downloads.lightbend.com` with `-k` (TLS-verification disabled). Should use a verified mirror; `-k` is a security smell.
- **`spark-base/Dockerfile`** untars Spark into `/usr/bin/` (wrong directory by FHS convention; `/opt` is correct). Also does `echo "alias …" >> ~/.bashrc` for non-interactive containers — never executes.
- **`spark-master` / `spark-worker`** use **shell-form `CMD`** with `>> logs/spark-master.out` redirection. This (a) makes the container PID 1 a shell, breaking `docker stop` signal handling, and (b) sends Spark logs to a file inside the container rather than stdout — `docker logs` shows nothing.
- **`jupyterlab/Dockerfile`** does `ADD workspace/ ${SHARED_WORKSPACE}/` which **bakes notebooks into the image** but the same path is later mounted from the named volume in compose, masking the baked-in notebooks. Students see an empty workspace on first start.
- All `LABEL manteiner=…` (typo) and outdated `org.label-schema.url` pointing to the upstream fork.
- **No `HEALTHCHECK` directives** in any image.
- **Hardcoded versions** are scattered between `build/build.yml`, `build/build.sh`, the root `Dockerfile`, and the three compose files. There is no single source of truth.
- **No `.dockerignore`** at the build-context root → every `docker build .` ships `.git/`, `pdfs/` (5.7 MB of PDFs), `data.zip`, `.DS_Store`, IDE folders into the daemon. Massive context for nothing.

### 1.3 Build-tooling problems
- **Two near-identical scripts**: `build/build.sh` (uses `ggrep`, macOS+brew) and `build/build.linux.sh` (uses `grep`). Same logic, drift-prone.
- Scripts parse YAML by `grep -P` regex — fragile; breaks on whitespace changes.
- No `docker buildx` usage → **no multi-arch publishing**. This is the headline bug.
- No CI: there is no `.github/workflows/` directory.
- No tagging convention — images are pushed with floating tags (or never).

### 1.4 Repo-level cruft
- `data.zip` is a 4 KB **Git-LFS pointer** (per `.gitattributes`) — pulling it without LFS gives students a broken file. Either commit the actual data or remove it.
- `pdfs/` (5.7 MB, two course PDFs) lives in the build context.
- `.DS_Store` files committed in three places.
- `.gitignore` is the upstream Spark-project ignore (300 lines) instead of a project-appropriate one.
- README references `CONTRIBUTING.md` and `CONTRIBUTORS.md` — **neither exists**.
- README badges point to `andreper/...` Hub user (not `janez87`).
- `local/README.md` is a single line of all-caps prose, not real docs.
- Scattered `examples/`, `databricks/` notebooks under `build/workspace/` look like upstream leftovers — confirm with maintainer before keeping.
- `hadoop.env` is a 16-GB-NM, 8-vCore YARN config — wildly oversized for a student laptop.
- `.env` mixes Confluent variables with comments unrelated to this project (looks copy-pasted from confluentinc/cp-demo).

---

## 2. Target Directory Layout

```
spark-practice/
├── .dockerignore                       # NEW — slim build context
├── .editorconfig                       # NEW
├── .env.example                        # NEW — template, .env stays gitignored
├── .github/
│   └── workflows/
│       ├── build-and-push.yml          # NEW — multi-arch buildx on tag
│       ├── ci.yml                      # NEW — lint + smoke tests on PR
│       └── release.yml                 # NEW — GH release notes from tag
├── .gitattributes                      # SHRUNK — drop LFS unless needed
├── .gitignore                          # REWRITTEN — small, project-specific
├── CHANGELOG.md                        # NEW
├── CONTRIBUTING.md                     # NEW (currently dangling reference)
├── LICENSE
├── Makefile                            # NEW — single entry point
├── README.md                           # REWRITTEN — student-facing
├── compose/
│   ├── docker-compose.yml              # core: jupyterlab + spark cluster
│   ├── compose.kafka.yml               # overlay (Compose profile: kafka)
│   ├── compose.hdfs.yml                # overlay (Compose profile: hdfs)
│   └── compose.dev.yml                 # overlay for local builds (build:)
├── docs/
│   ├── images/
│   │   └── cluster-architecture.png
│   ├── quickstart.md                   # pull-path students
│   ├── build-from-source.md            # build-path maintainers
│   ├── troubleshooting.md
│   └── upgrading.md                    # breaking-changes guide
├── images/                             # was build/docker
│   ├── base/
│   │   ├── Dockerfile
│   │   └── README.md
│   ├── spark-base/
│   │   ├── Dockerfile
│   │   └── requirements.txt            # pinned Python deps (incl. shapely)
│   ├── spark-master/
│   │   └── Dockerfile
│   ├── spark-worker/
│   │   └── Dockerfile
│   └── jupyterlab/
│       ├── Dockerfile
│       ├── requirements.txt
│       └── kernels/                    # scala/R kernel install scripts
├── notebooks/                          # was build/workspace
│   ├── PS00 - Spark RDD 101.ipynb
│   ├── PS01 - Spark RDD 102.ipynb
│   ├── PS02 - Dataframe.ipynb
│   ├── PS02a - Analyze Soccer Data.ipynb
│   ├── PS02b - Analyze London Crime …ipynb
│   ├── PS03 - SparkSQL.ipynb
│   ├── examples/                       # kept only if still referenced
│   └── data/                           # gitignored, see scripts/fetch-data.sh
├── config/
│   ├── hadoop.env                      # right-sized for laptops
│   └── spark-defaults.conf             # NEW — central Spark tuning
├── scripts/
│   ├── fetch-data.sh                   # download datasets out-of-band
│   ├── smoke-test.sh                   # used by CI + Makefile target
│   └── version.sh                      # single source of truth for tags
└── tests/
    ├── smoke/
    │   ├── test_spark_master.sh
    │   ├── test_spark_worker.sh
    │   ├── test_jupyterlab.sh
    │   └── test_kafka_overlay.sh
    └── README.md
```

Renames at a glance: `build/docker/` → `images/`, `build/workspace/` → `notebooks/`, `build/build*.sh` → deleted in favour of `Makefile` + `scripts/`, all three top-level `docker-compose*.yml` → `compose/` with a profile-driven layout.

---

## 3. Base-Image & Versioning Strategy

### 3.1 Layer DAG

```
eclipse-temurin:17-jre-jammy   (upstream, multi-arch)
        │
        ▼
janez87/spark-base             (JDK + Python + Scala + Spark binary)
        ├──► janez87/spark-master
        ├──► janez87/spark-worker  (incl. shapely + Python deps)
        └──► janez87/jupyterlab    (+ Jupyter, kernels, notebooks)
```

The current `base` image (Java + Python + Scala) and `spark-base` (adds Spark) collapse into **one** `spark-base` image. The intermediate `base` image was only used to share the JDK+Python layer between Spark and JupyterLab; with a multi-arch base layer cached on Docker Hub, the savings are negligible compared to the maintenance cost of a second image.

**Why `eclipse-temurin:17-jammy` instead of `openjdk:8`:**
- Officially maintained, multi-arch (`amd64`, `arm64`, `ppc64le`, `s390x`).
- Spark 3.5+ supports Java 17 (Spark 3.0.0 → 3.5.x upgrade discussed in §6).
- Removes the QEMU-emulation slowness on Apple Silicon and Linux/arm64 — the headline pain point.

### 3.2 Versioning convention

All images published as:

```
janez87/<image>:<spark-version>-<image-revision>
janez87/<image>:<spark-version>            # moving alias to latest revision
janez87/<image>:latest                     # moving alias to latest stable
```

Examples:
```
janez87/spark-base:3.5.1-1
janez87/spark-base:3.5.1
janez87/spark-base:latest
```

**Single source of truth**: `scripts/version.sh` exports `SPARK_VERSION`, `HADOOP_VERSION`, `SCALA_VERSION`, `JUPYTERLAB_VERSION`, `IMAGE_REVISION`, `REGISTRY=docker.io/janez87`. It is `source`d by the Makefile, by every Dockerfile via `--build-arg`, and by the GH Actions workflow. `build/build.yml` and the duplicated `case` blocks in `build*.sh` go away.

### 3.3 Multi-arch publish flow

1. `docker buildx create --use --name spark-builder --driver docker-container` (CI bootstrap).
2. For each image, `docker buildx build --platform linux/amd64,linux/arm64 --push -t janez87/<img>:<tag> -t janez87/<img>:latest .`
3. Use `--cache-to type=registry,ref=janez87/<img>:buildcache,mode=max` and `--cache-from` to speed up CI rebuilds across runs.
4. Manifest list ensures `docker pull janez87/spark-master` resolves to the native arch on every host — fixing the "slow on non-OSX" problem.

### 3.4 Trigger model

| Event                        | Workflow              | Action                                                                       |
|------------------------------|-----------------------|------------------------------------------------------------------------------|
| Push to `main`               | `ci.yml`              | Lint Dockerfiles (`hadolint`), validate compose, build amd64 only, smoke test |
| PR                           | `ci.yml`              | Same as above                                                                |
| Tag `v*.*.*`                 | `build-and-push.yml`  | Build multi-arch, tag with version + `latest`, push to Hub                   |
| Tag `v*.*.*`                 | `release.yml`         | Generate GitHub release with image digests                                   |
| Weekly schedule              | `build-and-push.yml`  | Rebuild `latest` to pull in upstream patches                                 |

Secrets needed: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` (read-write scoped to `janez87/spark-*`, `janez87/jupyterlab`).

---

## 4. Docker Compose Redesign

### 4.1 File layout

- `compose/docker-compose.yml` — the **only** file students must know about. Defines the core 4 services (`jupyterlab`, `spark-master`, `spark-worker-1`, `spark-worker-2`) using `image:` (Hub pull only).
- `compose/compose.kafka.yml` — `services:` for `zookeeper`, `kafka`, `schema-registry`. Activated by Compose **profile `kafka`**, so the same merged file works for everyone.
- `compose/compose.hdfs.yml` — `namenode`, `datanode`. Profile `hdfs`.
- `compose/compose.dev.yml` — overrides every service to use `build: ../images/<name>` instead of `image:`. Used only by maintainers via `make build`.

Students only ever run `make up` or `make up-kafka` / `make up-hdfs`. No `-f` juggling.

### 4.2 Environment variables

Single `.env.example` at the repo root, copied to `.env` by `make init`:

```
REGISTRY=docker.io/janez87
SPARK_TAG=3.5.1
JUPYTERLAB_TAG=4.1.0-spark-3.5.1
SPARK_WORKER_CORES=2
SPARK_WORKER_MEMORY=2G
SPARK_DRIVER_MEMORY=1G
SPARK_EXECUTOR_MEMORY=1G
JUPYTER_TOKEN=                 # blank = no auth (lab default)
JUPYTER_PORT=8888
SPARK_MASTER_UI_PORT=8080
WORKERS=2                      # used by `docker compose up --scale`
```

All compose files reference `${VAR}` — no version literals inside YAML.

### 4.3 Volumes

- `notebooks` → bind mount `../notebooks:/home/jovyan/work` (read-write so students keep edits on host).
- `data` → bind mount `../notebooks/data:/home/jovyan/work/data` (gitignored; `make fetch-data` populates it).
- `spark-events` → named volume shared between master + workers for History Server (future).
- Drop the misleadingly-named `hadoop-distributed-file-system` volume; replace with `lab-workspace` (named volume only used when bind-mounts are unwanted).

### 4.4 Health checks

| Service       | Healthcheck                                                           |
|---------------|-----------------------------------------------------------------------|
| `spark-master`| `curl -fsS http://localhost:8080/ \|\| exit 1` (UI port)              |
| `spark-worker`| `curl -fsS http://localhost:8081/ \|\| exit 1`                        |
| `jupyterlab`  | `curl -fsS http://localhost:8888/api \|\| exit 1`                     |
| `kafka`       | `kafka-broker-api-versions --bootstrap-server localhost:9092`         |
| `zookeeper`   | `echo ruok \| nc -w 2 localhost 2181 \| grep -q imok`                 |
| `namenode`    | `curl -fsS http://localhost:9870/ \|\| exit 1`                        |

Workers and JupyterLab declare `depends_on: { spark-master: { condition: service_healthy } }` so `docker compose up` does not race.

### 4.5 Profiles & scaling

- Default profile: jupyterlab + 1 master + 2 workers.
- `--profile kafka` adds Kafka stack.
- `--profile hdfs` adds HDFS stack.
- Workers are scaled with `docker compose up --scale spark-worker=N`; the compose file declares **one** `spark-worker` service (no more `spark-worker-1` / `spark-worker-2` duplication).

### 4.6 Makefile targets (preview)

```
make help
make init                  # copy .env.example → .env
make pull                  # docker pull all images from janez87/
make up                    # docker compose up -d (core)
make up-kafka              # core + kafka profile
make up-hdfs               # core + hdfs profile
make down                  # stop + remove containers
make logs SERVICE=jupyterlab
make build                 # local build via compose.dev.yml
make build-IMAGE=jupyterlab
make push TAG=3.5.1-1      # buildx push multi-arch (maintainers)
make smoke                 # run tests/smoke/*.sh against running stack
make clean                 # down + remove volumes
make fetch-data            # download class datasets into notebooks/data
```

---

## 5. File-by-file Change List

### 5.1 Create

| Path                                       | Reason                                                                       |
|--------------------------------------------|------------------------------------------------------------------------------|
| `.dockerignore`                            | Strip `.git`, `pdfs/`, `notebooks/data/`, `.DS_Store`, IDE dirs from context |
| `.editorconfig`                            | Consistent indentation across YAML / Dockerfiles / shell                     |
| `.env.example`                             | Template students copy to `.env`                                             |
| `.github/workflows/ci.yml`                 | Lint + smoke on PR                                                           |
| `.github/workflows/build-and-push.yml`     | Multi-arch build + push on tag                                               |
| `.github/workflows/release.yml`            | Auto-generate GH release notes                                               |
| `Makefile`                                 | Single entry point, replaces both `build*.sh` scripts                        |
| `CONTRIBUTING.md`                          | Resolve dangling README link; document tag → release flow                    |
| `CHANGELOG.md`                             | Track image revisions over time                                              |
| `compose/docker-compose.yml`               | Core stack, Hub-only                                                         |
| `compose/compose.kafka.yml`                | Kafka overlay (profile)                                                      |
| `compose/compose.hdfs.yml`                 | HDFS overlay (profile)                                                       |
| `compose/compose.dev.yml`                  | Maintainer overlay using `build:`                                            |
| `images/spark-base/requirements.txt`       | Pin Python deps (numpy, pandas, **shapely**, etc.) — replaces root Dockerfile |
| `images/jupyterlab/requirements.txt`       | Pin Jupyter + kernel deps                                                    |
| `images/jupyterlab/kernels/install-scala.sh` | Extracted kernel-install logic                                             |
| `images/jupyterlab/kernels/install-r.sh`   | Extracted kernel-install logic                                               |
| `config/spark-defaults.conf`               | Central tuning instead of compose env vars                                   |
| `scripts/version.sh`                       | Single source of truth for all version pins                                  |
| `scripts/fetch-data.sh`                    | Pull datasets out-of-band; replaces `data.zip` LFS file                      |
| `scripts/smoke-test.sh`                    | One-shot driver for `tests/smoke/*.sh`                                       |
| `tests/smoke/test_spark_master.sh`         | Hit `:8080`, parse worker count from JSON                                    |
| `tests/smoke/test_spark_worker.sh`         | Hit `:8081`                                                                  |
| `tests/smoke/test_jupyterlab.sh`           | Hit `:8888/api`, run `pyspark` 1+1 in a kernel                               |
| `tests/smoke/test_kafka_overlay.sh`        | Produce + consume on a topic                                                 |
| `docs/quickstart.md`                       | Pull-path student guide                                                      |
| `docs/build-from-source.md`                | Maintainer guide                                                             |
| `docs/troubleshooting.md`                  | Common failures (port conflicts, arm64 emulation, low memory)                |
| `docs/upgrading.md`                        | Breaking-change guide for current users                                      |

### 5.2 Modify

| Path                                       | Change                                                                       |
|--------------------------------------------|------------------------------------------------------------------------------|
| `images/base/Dockerfile` (was `build/docker/base/`) | Switch base to `eclipse-temurin:17-jammy`; drop `-k` from curl; install via apt-pinned versions; multi-arch friendly |
| `images/spark-base/Dockerfile`             | Move Spark to `/opt/spark`; switch to exec-form `CMD`; install Python deps from `requirements.txt`; add `HEALTHCHECK`; drop alias-to-bashrc trick |
| `images/spark-master/Dockerfile`           | Exec-form `CMD`, log to stdout (no `>>` redirect), `HEALTHCHECK`, drop outdated labels |
| `images/spark-worker/Dockerfile`           | Same as master; **fold root `Dockerfile`'s shapely install into requirements.txt** |
| `images/jupyterlab/Dockerfile`             | Remove `ADD workspace/` (notebooks live on bind mount); fix kernel install scripts; pin versions; add `HEALTHCHECK` |
| `config/hadoop.env`                        | Right-size for laptops (2 GB NM, 2 vCore); drop YARN settings unused in the lab |
| `README.md`                                | Rewrite: students-only TL;DR, Mermaid architecture diagram, link to `docs/`, fix Hub-user references (`janez87`, not `andreper`) |
| `.gitignore`                               | Cut to ~30 lines: Python, Jupyter checkpoints, `.env`, `notebooks/data/`, OS junk |
| `.gitattributes`                           | Drop LFS rules unless `data.zip` is genuinely re-introduced                  |

### 5.3 Delete

| Path                                       | Reason                                                                       |
|--------------------------------------------|------------------------------------------------------------------------------|
| `Dockerfile` (root)                        | Single-purpose patch; merged into `images/spark-worker/` via requirements.txt |
| `docker-compose.yml` (root)                | Replaced by `compose/docker-compose.yml`                                     |
| `docker-compose.kafka.yml` (root)          | Replaced by `compose/compose.kafka.yml`; broken hostname/mounts fixed in rewrite |
| `docker-compose.hdfs.yml` (root)           | Replaced by `compose/compose.hdfs.yml`                                       |
| `build/build.sh`                           | Replaced by `Makefile` (`make build`)                                        |
| `build/build.linux.sh`                     | Same — and removes the macOS/Linux fork                                      |
| `build/build.yml`                          | Replaced by `scripts/version.sh`                                             |
| `build/.DS_Store`, `build/workspace/.DS_Store`, root `.DS_Store` | Filesystem cruft                                       |
| `data.zip` (root, 4 KB LFS pointer)        | Move data fetching to `scripts/fetch-data.sh`                                |
| `pdfs/` (5.7 MB course slides)             | Course material doesn't belong in build context; move to a release attachment or vault |
| `local/README.md`                          | Replaced by proper `docs/quickstart.md` section about bind mounts            |
| `.env`                                     | Contains stale Confluent demo vars; replaced by `.env.example` (the real `.env` stays gitignored) |
| `hadoop.env` (root)                        | Moved to `config/hadoop.env` and trimmed                                     |
| `build/workspace/databricks/`              | Confirm with maintainer — appears to be upstream leftover unrelated to course |
| `build/workspace/examples/`                | Same — confirm before removing                                               |

---

## 6. Breaking Changes & Migration Notes

These belong in `docs/upgrading.md` and the v1.0 release notes:

1. **Image registry/tag scheme changed.** Old: `janez87/spark-master` (untagged), `janez87/jupyterlab:3.0.0-spark-3.0.0`. New: `janez87/spark-master:<spark-version>`. Anyone with old `docker-compose.yml` pinned to floating tags will silently get the new image; pin explicitly during the transition.

2. **Spark 3.0.0 → 3.5.x bump** (recommended as part of the same release). Notebooks will mostly run unchanged, but:
   - Java 8 → Java 17 (Spark 3.5 supports both, but 17 is now default).
   - Hadoop 2.x → 3.3.x in the bundled binaries.
   - Some PySpark APIs deprecated in 3.0 are gone in 3.5 (notebooks should be smoke-tested manually before tagging).
   Keep a `spark-3.0` branch / tag for students mid-semester who can't migrate.

3. **Compose file paths moved** (`./docker-compose.yml` → `./compose/docker-compose.yml`). Any external script doing `docker compose -f docker-compose.yml ...` breaks. The `Makefile` is the supported entry point.

4. **Spark workers no longer numbered.** `spark-worker-1` and `spark-worker-2` become a single `spark-worker` service scaled with `--scale spark-worker=N`. Anything addressing workers by container name (e.g. `docker exec spark-worker-1 ...`) needs to switch to `docker compose exec --index 1 spark-worker ...`.

5. **JupyterLab notebooks no longer baked into the image.** Students must clone the repo (or download the `notebooks/` tarball from the GH release) for the `notebooks/` bind mount to work. The "pull-only, no-clone" path no longer ships notebooks. Documented in `docs/quickstart.md`.

6. **`data.zip` removed.** Students run `make fetch-data` (or `./scripts/fetch-data.sh`). External URL for the dataset must be confirmed with the maintainer before implementation — if hosting moves, this script becomes the only place to update.

7. **Kafka stack rewritten.** Single broker by default (was two with broken hostnames). Anything using `kafka2:9093` will break — use `kafka:9092`. ksqlDB and `cnfltraining/training-tools` removed; if any lab needs them, they come back behind a separate profile.

8. **`hadoop.env` slimmed.** YARN memory drops from 16 GB to 2 GB. Anyone running heavy MapReduce jobs in the HDFS overlay must override via `.env`.

9. **`.env` semantics change.** Old `.env` was checked in with Confluent demo defaults; new `.env` is gitignored, students copy from `.env.example`. Existing forks should `git rm --cached .env` and re-init.

10. **Multi-arch images replace OSX-only images.** First `docker pull` after the cut-over downloads new layers (no shared blobs with old amd64 images). Allow ~2 GB / student of bandwidth on the first lab session post-migration.

11. **CI requires `DOCKERHUB_TOKEN` secret.** Configure before tagging the first release, otherwise the workflow will fail and no images will be published.

---

## 7. Manual Checks Required After Execution

The execution agent (Claude Code) cannot validate these — flagged so the human maintainer runs them before tagging the first release:

- **Notebooks under Spark 3.5.x.** Open every `notebooks/PS*.ipynb`, restart the kernel, run-all. Watch for deprecation removals (especially RDD-API edge cases and `SparkContext.parallelize` overloads).
- **Dataset URL for `scripts/fetch-data.sh`.** The script will be scaffolded with a `TODO` placeholder URL — confirm the canonical source for the soccer / London-crime / wordcount datasets before students consume it.
- **`build/workspace/databricks/` and `build/workspace/examples/`.** Plan flags these as likely upstream leftovers. Decide whether to keep them under `notebooks/examples/` or delete entirely.
- **Docker Hub repository names** (`janez87/spark-base`, `…/spark-master`, `…/spark-worker`, `…/jupyterlab`). Confirm they exist on Hub and that the `DOCKERHUB_TOKEN` secret has push scope on each before the first tag.
- **GitHub Actions secrets**: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` must be added to the repo settings before merging to main.
- **Multi-arch smoke test.** CI builds amd64 only on PRs; the maintainer should run `docker buildx build --platform linux/arm64` locally on at least one image before tagging, to confirm arm64 actually builds.
