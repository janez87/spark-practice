# syntax=docker/dockerfile:1.6
ARG REGISTRY=janez87
ARG BASE_TAG=latest
FROM ${REGISTRY}/spark-practice-base:${BASE_TAG}

ARG BUILD_DATE
ARG SPARK_VERSION=3.5.1
ARG SCALA_VERSION=2.12.18
ARG ALMOND_VERSION=0.14.0-RC15
ARG INSTALL_R_KERNEL=false

LABEL org.opencontainers.image.title="spark-practice-jupyterlab" \
      org.opencontainers.image.description="JupyterLab + PySpark/Scala/(optional R) kernels for the spark-practice lab stack" \
      org.opencontainers.image.source="https://github.com/janez87/spark-practice" \
      org.opencontainers.image.created="${BUILD_DATE}"

ENV JUPYTER_PORT=8888 \
    PYSPARK_PYTHON=python3 \
    PYSPARK_DRIVER_PYTHON=python3 \
    SCALA_VERSION=${SCALA_VERSION} \
    ALMOND_VERSION=${ALMOND_VERSION} \
    SPARK_VERSION=${SPARK_VERSION}

# Python deps (JupyterLab, PySpark, common data libs)
COPY requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir -r /tmp/requirements.txt && \
    rm -f /tmp/requirements.txt

# Scala kernel (almond)
COPY kernels/install-scala.sh /tmp/install-scala.sh
RUN chmod +x /tmp/install-scala.sh && /tmp/install-scala.sh && rm -f /tmp/install-scala.sh

# Optional R kernel (off by default — heavy, rarely used in current notebooks)
COPY kernels/install-r.sh /tmp/install-r.sh
RUN chmod +x /tmp/install-r.sh && \
    if [ "${INSTALL_R_KERNEL}" = "true" ]; then /tmp/install-r.sh; fi && \
    rm -f /tmp/install-r.sh

EXPOSE 8888

WORKDIR ${SHARED_WORKSPACE}

HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=5 \
    CMD curl -fsS "http://localhost:${JUPYTER_PORT}/api" || exit 1

CMD ["bash", "-c", "exec jupyter lab --ip=0.0.0.0 --port=${JUPYTER_PORT} --no-browser --allow-root --ServerApp.token=${JUPYTER_TOKEN:-} --ServerApp.password=''"]
