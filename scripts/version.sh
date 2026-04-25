#!/usr/bin/env bash
# Single source of truth for image versions across Makefile, Dockerfiles,
# Compose files, and CI workflows. `source scripts/version.sh` to load.
set -euo pipefail

# Registry / namespace for published images
export REGISTRY="${REGISTRY:-janez87}"

# Apache Spark + bundled Hadoop
export SPARK_VERSION="${SPARK_VERSION:-3.5.1}"
export HADOOP_VERSION="${HADOOP_VERSION:-3}"

# Scala (for the Almond Jupyter kernel; Spark bundles its own copy)
export SCALA_VERSION="${SCALA_VERSION:-2.12.18}"
export ALMOND_VERSION="${ALMOND_VERSION:-0.14.0-RC15}"

# JupyterLab (Python package version)
export JUPYTERLAB_VERSION="${JUPYTERLAB_VERSION:-4.1.5}"

# Image revision — bump when rebuilding the same Spark version with a new layer
export IMAGE_REVISION="${IMAGE_REVISION:-1}"

# Composite tags
export SPARK_TAG="${SPARK_TAG:-${SPARK_VERSION}}"
export JUPYTERLAB_TAG="${JUPYTERLAB_TAG:-${JUPYTERLAB_VERSION}-spark-${SPARK_VERSION}}"
export BASE_TAG="${BASE_TAG:-latest}"

export BUILD_DATE="${BUILD_DATE:-$(date -u +'%Y-%m-%dT%H:%M:%SZ')}"

# Confluent Platform tag (Kafka overlay)
export CONFLUENT_TAG="${CONFLUENT_TAG:-7.5.3}"

# When sourced (not executed) we silently export. When executed, print.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    env | grep -E '^(REGISTRY|SPARK_|HADOOP_|SCALA_|ALMOND_|JUPYTERLAB_|IMAGE_|BASE_|BUILD_DATE|CONFLUENT_)' | sort
fi
