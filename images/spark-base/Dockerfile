# syntax=docker/dockerfile:1.6
ARG REGISTRY=janez87
ARG BASE_TAG=latest
FROM ${REGISTRY}/spark-practice-base:${BASE_TAG}

ARG BUILD_DATE
ARG SPARK_VERSION=3.5.1
ARG HADOOP_VERSION=3
ARG SPARK_HOME=/opt/spark

LABEL org.opencontainers.image.title="spark-practice-spark-base" \
      org.opencontainers.image.description="Apache Spark ${SPARK_VERSION} (Hadoop ${HADOOP_VERSION}) on the spark-practice base image" \
      org.opencontainers.image.source="https://github.com/janez87/spark-practice" \
      org.opencontainers.image.created="${BUILD_DATE}"

ENV SPARK_HOME=${SPARK_HOME} \
    SPARK_MASTER_HOST=spark-master \
    SPARK_MASTER_PORT=7077 \
    PYSPARK_PYTHON=python3 \
    PYSPARK_DRIVER_PYTHON=python3 \
    PATH=${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}

RUN set -eux; \
    curl -fsSL "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" -o /tmp/spark.tgz; \
    mkdir -p "${SPARK_HOME}"; \
    tar -xzf /tmp/spark.tgz -C "${SPARK_HOME}" --strip-components=1; \
    rm -f /tmp/spark.tgz; \
    mkdir -p "${SPARK_HOME}/logs" "${SPARK_HOME}/work"

COPY requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --no-cache-dir -r /tmp/requirements.txt && \
    rm -f /tmp/requirements.txt

WORKDIR ${SPARK_HOME}

CMD ["bash"]
