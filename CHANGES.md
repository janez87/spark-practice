# CHANGES — execution record for `refactor/lab-stack-v1`

Companion to `PLAN.md`. Tracks what was actually done, what was skipped, and where the implementation deviated from the plan.

Branch: `refactor/lab-stack-v1`
Commits (oldest → newest):
1. `Add refactor plan for lab stack v1` (PLAN.md only)
2. `Refactor: lab stack v1 (multi-arch, profile-driven Compose, CI/CD)` (full refactor)
3. `Fix: dry-run build issues found during execution` (post-build deviations)

## Final tree (highlights)

```
spark-practice/
├── .dockerignore .editorconfig .env.example .gitignore .gitattributes
├── .github/workflows/ {ci,build-and-push,release}.yml
├── .make/version.mk
├── CHANGELOG.md  CHANGES.md  CONTRIBUTING.md  LICENSE  Makefile  PLAN.md  README.md
├── compose/      docker-compose.yml + compose.{kafka,hdfs,dev}.yml
├── config/       hadoop.env, spark-defaults.conf
├── docs/         quickstart.md, build-from-source.md, troubleshooting.md, upgrading.md, images/
├── images/       base, spark-base, spark-master, spark-worker, jupyterlab
├── notebooks/    PS00–PS03, Start.ipynb, wordcount.py, examples/, databricks/
├── scripts/      version.sh, fetch-data.sh, smoke-test.sh
└── tests/smoke/  test_{spark_master,spark_worker,jupyterlab,kafka_overlay}.sh
```

## What was done

### §5.1 — Created
All files from the plan's "Create" list exist and are committed. Notable additions:
- `.make/version.mk` (not in plan): a Make-readable mirror of `scripts/version.sh`. The plan called for a single source of truth in `scripts/version.sh`; the Makefile can't `source` a bash script reliably across `gmake` / `bsdmake`, so the Make-include pattern is the standard fix. Both files document the link.
- `images/base/README.md` and `tests/README.md`: small READMEs scoped per directory, helpful while the layout is new.

### §5.2 — Modified
All entries from "Modify" applied. Notebook layout: notebooks moved to `notebooks/` via `git mv` so history is preserved.

### §5.3 — Deleted
All entries from "Delete" applied:
- Root `Dockerfile`, all three root `docker-compose*.yml`, `data.zip`, `pdfs/`, `local/README.md`, root `.env`, root `hadoop.env`, `build/build*.sh`, `build/build.yml`, all `build/.DS_Store` files, the empty `build/` and `local/` directories.
- `notebooks/databricks/` and `notebooks/examples/` are **kept** for now (see deviations below) — flagged for the maintainer to decide.

### Dry-run builds
All five images built clean with `docker build --no-cache` after two iterations of fixes:

| Image                                  | Result | Size      |
|----------------------------------------|--------|-----------|
| `janez87/spark-practice-base`          | OK     | 343 MB    |
| `janez87/spark-practice-spark-base`    | OK     | 1.05 GB   |
| `janez87/spark-practice-spark-master`  | OK     | 1.05 GB   |
| `janez87/spark-practice-spark-worker`  | OK     | 1.05 GB   |
| `janez87/spark-practice-jupyterlab`    | OK     | 1.42 GB   |

Tagged `:dryrun` for verification; not pushed.

## Deviations from the plan

### 1. Scala dropped from `images/base`

**Plan**: keep Scala in the base image, install via `.deb` from a verified mirror.
**Actual**: Scala removed entirely from the base image.

**Reason**: the `scala-2.12.18.deb` declares `Depends: java8-runtime-headless`, which is not satisfiable on the new `eclipse-temurin:17-jre-jammy` base. The original base installed Scala system-wide but **nothing actually consumed it**: Spark bundles its own copy at `${SPARK_HOME}/jars/scala-*.jar`, and the JupyterLab Scala kernel installs its own Scala via Coursier (almond). Removing the system Scala saved ~120 MB and removed a transitive Java-version constraint. Documented in `images/base/Dockerfile` and `images/base/README.md`.

### 2. JupyterLab Scala kernel uses the JVM coursier launcher (not native `cs`)

**Plan**: install almond via the `cs` native binary.
**Actual**: install via the `coursier` JVM launcher (one shell-script wrapper around the JAR).

**Reason**: Coursier publishes the native `cs` binary for `x86_64 Linux` and `apple-darwin` only — there is **no `cs-aarch64-pc-linux`** asset, which would break our `linux/arm64` build (the headline goal of this refactor). The JVM launcher is portable across amd64 and arm64 since we already have Java 17. Slightly slower startup, identical end result.

### 3. `.make/version.mk` introduced

**Plan**: `scripts/version.sh` is the only source of truth.
**Actual**: `.make/version.mk` is a parallel file the Makefile includes.

**Reason**: GNU Make can't reliably `source` a bash script across all targets without spawning a sub-shell per recipe (which loses exports). Two-file pattern with a header comment in both files documenting the link. To keep them in sync, edit `scripts/version.sh` and copy the same defaults into `.make/version.mk`. A pre-commit hook to enforce sync is left as a future exercise.

### 4. `notebooks/databricks/` and `notebooks/examples/` retained

**Plan**: §5.3 flagged these as "confirm with maintainer; appear to be upstream leftovers."
**Actual**: kept in place.

**Reason**: the user asked to proceed without flagging these individually. They are out of the way under `notebooks/` and easy to delete in a follow-up PR. **Maintainer decision needed.**

### 5. Defaults for `INSTALL_R_KERNEL`

**Plan**: keep R kernel for SparkR labs.
**Actual**: build arg `INSTALL_R_KERNEL=false` by default; the install script exists at `images/jupyterlab/kernels/install-r.sh` and runs only when the build arg is `true`.

**Reason**: only `notebooks/examples/sparkr.ipynb` uses R; the PS0x course notebooks do not. R + IRkernel + SparkR adds ~400 MB and ~10 min to the build. Maintainer can flip the arg if a future course needs it; the path is fully wired (Dockerfile, install script, Makefile build args).

## What was skipped

Nothing from the plan was skipped outright. The following are scaffolded but require human action to be useful:

- **`scripts/fetch-data.sh`**: contains a `TODO` placeholder for the dataset URL. The script is a no-op stub that exits cleanly with a help message until `DATA_URL` is set or the placeholder is replaced.
- **GitHub Actions secrets** (`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`): repository-level secrets, cannot be created from a code change. `build-and-push.yml` will fail until they are added (Repo Settings → Secrets and variables → Actions).
- **Docker Hub repositories**: the workflows assume `janez87/spark-practice-{base,spark-base,spark-master,spark-worker,jupyterlab}` exist. If they don't, the first push will create them under Docker Hub's default visibility (verify before tagging the first release).

## Manual checks required (per PLAN §7)

> **The execution agent (Claude Code) cannot validate these — please confirm before tagging the first release.**

1. **Notebooks under Spark 3.5.x**: open every `notebooks/PS*.ipynb`, restart the kernel, run-all. Watch for deprecation removals (especially RDD-API edge cases and `SparkContext.parallelize` overloads).
2. **Dataset URL** for `scripts/fetch-data.sh`: replace the `TODO` placeholder with the canonical source URL for the soccer / London-crime / wordcount datasets.
3. **`notebooks/databricks/` and `notebooks/examples/`**: decide whether to keep, move under `notebooks/optional/`, or delete.
4. **Docker Hub repository names**: confirm `janez87/spark-practice-*` exist on Hub, and the Hub token has push scope on each.
5. **GitHub Actions secrets**: add `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` to repo settings before merging to main.
6. **arm64 build verification**: CI builds amd64 only on PRs. Run `docker buildx build --platform linux/arm64 images/<name>` locally on at least one image (the base + jupyterlab are the most likely to surface arch-specific issues).
7. **First-time stack smoke**: run `make build && make up && make smoke` end-to-end on a clean machine before tagging — the smoke tests assume the stack is up but don't bring it up.

## Known follow-ups (out of scope for this PR)

- Pre-commit hook to validate `scripts/version.sh` ↔ `.make/version.mk` stay in sync.
- `make` target to regenerate `.make/version.mk` from `scripts/version.sh` automatically.
- Add a `notebooks/data/` placeholder `.gitkeep` so the bind-mount target exists pre-fetch (currently relies on `make fetch-data` or `mkdir`).
- Consider switching to the `jupyter/pyspark-notebook` upstream image as the JupyterLab base — would shrink the image significantly but couples us to their release cadence.
- `docker compose` health-aware `wait-for-it` patterns in the smoke tests (currently a fixed `sleep 20` in CI — could be tightened).
