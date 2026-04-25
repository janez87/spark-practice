#!/usr/bin/env bash
# Install the almond Scala kernel for Jupyter via Coursier.
# Uses the JVM-based `coursier` launcher (portable across amd64 and arm64
# Linux — the native `cs` binary is published for x86_64 Linux only).
set -euo pipefail

: "${SCALA_VERSION:?SCALA_VERSION must be set}"
: "${ALMOND_VERSION:?ALMOND_VERSION must be set}"

curl -fsSL "https://github.com/coursier/coursier/releases/latest/download/coursier" \
    -o /usr/local/bin/coursier
chmod +x /usr/local/bin/coursier

coursier launch --fork "almond:${ALMOND_VERSION}" --scala "${SCALA_VERSION}" -- \
    --display-name "Scala ${SCALA_VERSION}" \
    --install --force

rm -f /usr/local/bin/coursier
