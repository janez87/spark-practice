# Contributing

## Reporting a problem

Open an issue on GitHub. For lab-stack failures, please include:
- Output of `docker --version` and `docker compose version`.
- Your host architecture (`uname -m`).
- The output of `docker compose -f compose/docker-compose.yml ps`.
- Relevant logs: `make logs SERVICE=<name>` (last 50 lines is enough).

## Proposing a change

1. Fork + branch off `main` (e.g. `feature/spark-3.5.2-bump`).
2. Make your change. If you touch a Dockerfile or Compose file, run:
   ```bash
   make build
   make up
   make smoke
   make down
   ```
3. Update `CHANGELOG.md` under "Unreleased".
4. Open a PR. CI runs `hadolint`, validates Compose, builds amd64, and runs the smoke suite.

## Cutting a release (maintainers)

See [`docs/build-from-source.md`](docs/build-from-source.md#cutting-a-release).

The short version:
1. Move "Unreleased" entries in `CHANGELOG.md` under a new dated heading.
2. Bump versions in `scripts/version.sh` + `.make/version.mk` if needed.
3. Tag: `git tag v3.5.1-1 && git push --tags`.
4. CI builds multi-arch and publishes to Docker Hub.
5. The release workflow drafts GitHub release notes — review and publish.

## Adding a new dependency

- **Python (Spark side)**: append to `images/spark-base/requirements.txt` with a pinned version.
- **Python (Jupyter side)**: append to `images/jupyterlab/requirements.txt`.
- **System packages**: edit the relevant Dockerfile under `images/` and bump the image revision (`IMAGE_REVISION`) in `scripts/version.sh`.

## Style

- Markdown wraps at sentence boundaries, not 80 columns.
- Bash scripts: `set -euo pipefail`, shellcheck-clean.
- Dockerfiles: pinned major versions, multi-arch friendly (no `arch`-specific `RUN`s without an `if` guard).
- One change per PR. If you bump Spark **and** rewrite the Kafka overlay, that's two PRs.
