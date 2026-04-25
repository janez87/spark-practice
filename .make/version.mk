# Auto-derived from scripts/version.sh. The Make-include keeps a single
# source of truth without forcing every target to call `source` explicitly.
#
# To regenerate by hand:  bash scripts/version.sh > /dev/null && env | grep -E '^(REGISTRY|SPARK_|HADOOP_|SCALA_|ALMOND_|JUPYTERLAB_|IMAGE_|BASE_|BUILD_DATE|CONFLUENT_)' | sort

REGISTRY          ?= janez87
SPARK_VERSION     ?= 3.5.1
HADOOP_VERSION    ?= 3
SCALA_VERSION     ?= 2.12.18
ALMOND_VERSION    ?= 0.14.0-RC15
JUPYTERLAB_VERSION ?= 4.1.5
IMAGE_REVISION    ?= 1
SPARK_TAG         ?= $(SPARK_VERSION)
JUPYTERLAB_TAG    ?= $(JUPYTERLAB_VERSION)-spark-$(SPARK_VERSION)
BASE_TAG          ?= latest
BUILD_DATE        ?= $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
CONFLUENT_TAG     ?= 7.5.3
