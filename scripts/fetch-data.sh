#!/usr/bin/env bash
# Download class datasets into notebooks/data so they appear inside the
# JupyterLab container at /opt/workspace/data.
#
# TODO(maintainer): replace the placeholder URL below with the canonical
# source URL for the soccer / London-crime / wordcount datasets used by
# the PS0x notebooks. Until then, this script is a no-op stub.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${REPO_ROOT}/notebooks/data"
mkdir -p "${DATA_DIR}"

# TODO: replace with real dataset source(s).
DATA_URL="${DATA_URL:-}"

if [[ -z "${DATA_URL}" ]]; then
    cat <<EOF >&2
fetch-data.sh: no DATA_URL configured.

Set the DATA_URL env var to a tarball/zip download, e.g.:
    DATA_URL=https://example.com/spark-practice-data.zip ./scripts/fetch-data.sh

Or edit scripts/fetch-data.sh and replace the TODO placeholder.
EOF
    exit 0
fi

ARCHIVE="${DATA_DIR}/_download.$$"
trap 'rm -f "${ARCHIVE}"' EXIT

echo "Downloading datasets from ${DATA_URL}…"
curl -fsSL "${DATA_URL}" -o "${ARCHIVE}"

case "${DATA_URL}" in
    *.zip)  unzip -o "${ARCHIVE}" -d "${DATA_DIR}" ;;
    *.tgz|*.tar.gz)  tar -xzf "${ARCHIVE}" -C "${DATA_DIR}" ;;
    *.tar)  tar -xf  "${ARCHIVE}" -C "${DATA_DIR}" ;;
    *) echo "Unknown archive format for ${DATA_URL}" >&2; exit 1 ;;
esac

echo "Datasets extracted into ${DATA_DIR}"
