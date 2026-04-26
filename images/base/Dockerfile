# syntax=docker/dockerfile:1.6
ARG JAVA_BASE_IMAGE=eclipse-temurin:17-jre-jammy
FROM ${JAVA_BASE_IMAGE}

ARG BUILD_DATE
ARG SHARED_WORKSPACE=/opt/workspace

LABEL org.opencontainers.image.title="spark-practice-base" \
      org.opencontainers.image.description="Base image: JDK 17 + Python 3 for spark-practice lab stack" \
      org.opencontainers.image.source="https://github.com/janez87/spark-practice" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.created="${BUILD_DATE}"

# Note: no system-wide Scala here. Spark bundles its own; the JupyterLab
# Scala kernel installs its own via Coursier (almond). The old base image
# pulled in the Scala .deb but nothing actually consumed it, and the .deb
# pins to Java 8 — incompatible with this Java 17 base.

ENV DEBIAN_FRONTEND=noninteractive \
    SHARED_WORKSPACE=${SHARED_WORKSPACE}

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        python3 \
        python3-pip \
        python3-dev \
        tini && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    mkdir -p ${SHARED_WORKSPACE}/data && \
    rm -rf /var/lib/apt/lists/*

VOLUME ${SHARED_WORKSPACE}

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash"]
