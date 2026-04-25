#!/usr/bin/env bash
# Install the IRkernel for Jupyter and the SparkR package.
set -euo pipefail

: "${SPARK_VERSION:?SPARK_VERSION must be set}"

apt-get update
apt-get install -y --no-install-recommends r-base r-base-dev
rm -rf /var/lib/apt/lists/*

R -e "install.packages('IRkernel', repos='https://cloud.r-project.org')"
R -e "IRkernel::installspec(displayname = 'R', user = FALSE)"

curl -fsSL "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/SparkR_${SPARK_VERSION}.tar.gz" -o /tmp/sparkr.tar.gz
R CMD INSTALL /tmp/sparkr.tar.gz
rm -f /tmp/sparkr.tar.gz
