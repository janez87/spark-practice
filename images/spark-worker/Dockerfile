# syntax=docker/dockerfile:1.6
ARG REGISTRY=janez87
ARG SPARK_BASE_TAG=latest
FROM ${REGISTRY}/spark-practice-spark-base:${SPARK_BASE_TAG}

ARG BUILD_DATE

LABEL org.opencontainers.image.title="spark-practice-spark-worker" \
      org.opencontainers.image.description="Spark standalone worker for the spark-practice lab stack" \
      org.opencontainers.image.source="https://github.com/janez87/spark-practice" \
      org.opencontainers.image.created="${BUILD_DATE}"

ENV SPARK_WORKER_WEBUI_PORT=8081 \
    SPARK_MASTER_HOST=spark-master \
    SPARK_MASTER_PORT=7077

EXPOSE 8081

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 \
    CMD curl -fsS "http://localhost:${SPARK_WORKER_WEBUI_PORT}/" || exit 1

CMD ["bash", "-c", "exec ${SPARK_HOME}/bin/spark-class org.apache.spark.deploy.worker.Worker --webui-port ${SPARK_WORKER_WEBUI_PORT} spark://${SPARK_MASTER_HOST}:${SPARK_MASTER_PORT}"]
