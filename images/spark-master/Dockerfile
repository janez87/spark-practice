# syntax=docker/dockerfile:1.6
ARG REGISTRY=janez87
ARG SPARK_BASE_TAG=latest
FROM ${REGISTRY}/spark-practice-spark-base:${SPARK_BASE_TAG}

ARG BUILD_DATE

LABEL org.opencontainers.image.title="spark-practice-spark-master" \
      org.opencontainers.image.description="Spark standalone master for the spark-practice lab stack" \
      org.opencontainers.image.source="https://github.com/janez87/spark-practice" \
      org.opencontainers.image.created="${BUILD_DATE}"

ENV SPARK_MASTER_WEBUI_PORT=8080 \
    SPARK_MASTER_PORT=7077

EXPOSE 7077 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=5 \
    CMD curl -fsS "http://localhost:${SPARK_MASTER_WEBUI_PORT}/" || exit 1

CMD ["bash", "-c", "exec ${SPARK_HOME}/bin/spark-class org.apache.spark.deploy.master.Master --host 0.0.0.0 --port ${SPARK_MASTER_PORT} --webui-port ${SPARK_MASTER_WEBUI_PORT}"]
