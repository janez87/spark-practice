# Building from source

For maintainers and anyone debugging the images themselves. **Students do not need this.**

## Local build (single-arch)

```bash
make build                      # via compose.dev.yml — fast for your host arch
# or, image by image:
make build-base
make build-spark-base
make build-spark-master
make build-spark-worker
make build-jupyterlab
```

The image graph is:

```
spark-practice-base
├── spark-practice-spark-base
│   ├── spark-practice-spark-master
│   └── spark-practice-spark-worker
└── spark-practice-jupyterlab
```

so `build-spark-master` will build `base` and `spark-base` first if needed.

## Bumping versions

Edit `scripts/version.sh` (and the mirrored defaults in `.make/version.mk`):

```bash
SPARK_VERSION=3.5.2
JUPYTERLAB_VERSION=4.1.6
```

Then rebuild:
```bash
make build
make smoke
```

If the bump is a Spark major/minor, **manually open every notebook under `notebooks/`** and run-all to confirm there are no API regressions.

## Multi-arch publish (manual)

CI does this automatically on tag push. To do it by hand:

```bash
docker login -u janez87
make buildx-init
make push PUSH_TAG=3.5.1-1
```

This builds `linux/amd64` + `linux/arm64` for every image and pushes both tags (`3.5.1-1` and `latest`) to Docker Hub under the `janez87/spark-practice-*` repos. Each build also writes a registry-cache layer (`:buildcache`) used by subsequent builds.

## CI

Three workflows, all in `.github/workflows/`:

| Workflow              | Trigger             | What it does                                      |
|-----------------------|---------------------|---------------------------------------------------|
| `ci.yml`              | push / PR           | hadolint + compose validate + amd64 build + smoke |
| `build-and-push.yml`  | tag `v*.*.*`, weekly | multi-arch build + push to Docker Hub             |
| `release.yml`         | tag `v*.*.*`        | generate GitHub release notes                     |

Required secrets (Repo settings → Secrets and variables → Actions):
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN` — read-write scoped to the `janez87/spark-practice-*` repos.

## Cutting a release

1. Bump versions in `scripts/version.sh` + `.make/version.mk`.
2. Update `CHANGELOG.md` (under "Unreleased").
3. PR + merge to `main` (CI must be green).
4. Tag: `git tag v3.5.1-1 && git push --tags`
5. Watch `build-and-push.yml` — typical multi-arch run is 15–25 min.
6. Verify on Docker Hub that all five repos have the new tag.

## Adding a new image

1. Create `images/<name>/Dockerfile` (and any helpers like `requirements.txt`).
2. Add a `build-<name>` target to the `Makefile`.
3. Append `<name>` to the `IMAGES :=` list (drives `make push`).
4. Add a service block in `compose/docker-compose.yml` (or a new overlay).
5. Add a row to the `matrix.include` list in `.github/workflows/build-and-push.yml`.
6. Add a smoke test under `tests/smoke/test_<name>.sh`.
