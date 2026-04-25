# `spark-practice-base`

Shared base layer for the Spark/JupyterLab lab stack.

Contents:
- Eclipse Temurin JDK 17 (multi-arch: `linux/amd64`, `linux/arm64`)
- Python 3 + pip
- Scala (version controlled by `SCALA_VERSION` build arg)
- `tini` as PID 1 for clean signal handling

Build args:
- `JAVA_BASE_IMAGE` (default `eclipse-temurin:17-jre-jammy`)
- `SCALA_VERSION` (default `2.12.18`)
- `SHARED_WORKSPACE` (default `/opt/workspace`)
- `BUILD_DATE` (set by CI; injected as OCI label)

This image is rarely run directly — it is consumed by `spark-base` and `jupyterlab`.
