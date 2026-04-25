# syntax=docker/dockerfile:1.6
ARG JAVA_BASE_IMAGE=eclipse-temurin:17-jre-jammy
FROM ${JAVA_BASE_IMAGE}

ARG BUILD_DATE
ARG SCALA_VERSION=2.12.18
ARG SHARED_WORKSPACE=/opt/workspace

LABEL org.opencontainers.image.title="spark-practice-base" \
      org.opencontainers.image.description="Base image: JDK 17 + Python 3 + Scala for spark-practice lab stack" \
      org.opencontainers.image.source="https://github.com/janez87/spark-practice" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.created="${BUILD_DATE}"

ENV DEBIAN_FRONTEND=noninteractive \
    SHARED_WORKSPACE=${SHARED_WORKSPACE} \
    SCALA_HOME=/usr/share/scala

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
    mkdir -p ${SHARED_WORKSPACE}/data

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in \
        amd64|arm64) ;; \
        *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/scala/scala/releases/download/v${SCALA_VERSION}/scala-${SCALA_VERSION}.deb" -o /tmp/scala.deb && \
    apt-get install -y --no-install-recommends /tmp/scala.deb && \
    rm -f /tmp/scala.deb && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=${PATH}:${SCALA_HOME}/bin

VOLUME ${SHARED_WORKSPACE}

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash"]
