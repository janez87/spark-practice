#!/usr/bin/env bash
# Install the almond Scala kernel for Jupyter.
# Pinned versions come from build args; this script reads them from env.
set -euo pipefail

: "${SCALA_VERSION:?SCALA_VERSION must be set}"
: "${ALMOND_VERSION:?ALMOND_VERSION must be set}"

COURSIER_URL="https://github.com/coursier/coursier/releases/latest/download/cs-x86_64-pc-linux"
arch="$(dpkg --print-architecture)"
if [[ "${arch}" == "arm64" ]]; then
    COURSIER_URL="https://github.com/coursier/coursier/releases/latest/download/cs-aarch64-pc-linux"
fi

curl -fsSL "${COURSIER_URL}" -o /usr/local/bin/cs
chmod +x /usr/local/bin/cs

cs launch --fork "almond:${ALMOND_VERSION}" --scala "${SCALA_VERSION}" -- \
    --display-name "Scala ${SCALA_VERSION}" \
    --install --force

rm -f /usr/local/bin/cs
