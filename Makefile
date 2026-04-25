# spark-practice — single entry point for student + maintainer workflows.
#
# Most students only need: `make init` once, then `make up` / `make down`.
# Maintainers add: `make build`, `make push TAG=…`, `make smoke`.

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

REPO_ROOT      := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
COMPOSE_DIR    := $(REPO_ROOT)/compose
COMPOSE_CORE   := -f $(COMPOSE_DIR)/docker-compose.yml
COMPOSE_KAFKA  := $(COMPOSE_CORE) -f $(COMPOSE_DIR)/compose.kafka.yml
COMPOSE_HDFS   := $(COMPOSE_CORE) -f $(COMPOSE_DIR)/compose.hdfs.yml
COMPOSE_DEV    := $(COMPOSE_CORE) -f $(COMPOSE_DIR)/compose.dev.yml
ENV_FILE       := $(REPO_ROOT)/.env

# Pull versions from scripts/version.sh so this file isn't a second source of truth.
include $(REPO_ROOT)/.make/version.mk

DOCKER_COMPOSE := docker compose --env-file $(ENV_FILE)

PLATFORMS ?= linux/amd64,linux/arm64
PUSH_TAG  ?= $(SPARK_TAG)

IMAGES := base spark-base spark-master spark-worker jupyterlab

##@ Help

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN{FS=":.*##"; printf "\nUsage: make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*##/{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2} /^##@/{printf "\n\033[1m%s\033[0m\n", substr($$0, 5)}' $(MAKEFILE_LIST)

##@ Setup

.PHONY: init
init: ## Copy .env.example to .env (one-time setup).
	@if [[ -f $(ENV_FILE) ]]; then \
	    echo ".env already exists — leaving it alone."; \
	else \
	    cp $(REPO_ROOT)/.env.example $(ENV_FILE); \
	    echo "Created $(ENV_FILE) from .env.example. Edit as needed."; \
	fi

.PHONY: fetch-data
fetch-data: ## Download class datasets into notebooks/data.
	@bash $(REPO_ROOT)/scripts/fetch-data.sh

##@ Run (students)

.PHONY: pull
pull: ## docker pull every published image (no build).
	$(DOCKER_COMPOSE) $(COMPOSE_CORE) pull

.PHONY: up
up: ## Start the core stack (jupyterlab + spark master + workers).
	$(DOCKER_COMPOSE) $(COMPOSE_CORE) up -d
	@echo "JupyterLab → http://localhost:$${JUPYTER_PORT:-8888}"
	@echo "Spark UI   → http://localhost:$${SPARK_MASTER_UI_PORT:-8080}"

.PHONY: up-kafka
up-kafka: ## Start the core stack + kafka profile.
	$(DOCKER_COMPOSE) $(COMPOSE_KAFKA) --profile kafka up -d

.PHONY: up-hdfs
up-hdfs: ## Start the core stack + hdfs profile.
	$(DOCKER_COMPOSE) $(COMPOSE_HDFS) --profile hdfs up -d

.PHONY: down
down: ## Stop and remove containers (volumes preserved).
	$(DOCKER_COMPOSE) $(COMPOSE_KAFKA) -f $(COMPOSE_DIR)/compose.hdfs.yml --profile kafka --profile hdfs down

.PHONY: clean
clean: ## down + remove volumes + prune dangling images.
	$(DOCKER_COMPOSE) $(COMPOSE_KAFKA) -f $(COMPOSE_DIR)/compose.hdfs.yml --profile kafka --profile hdfs down -v
	docker image prune -f

.PHONY: logs
logs: ## Tail logs of SERVICE (default: jupyterlab). Usage: make logs SERVICE=spark-master
	$(DOCKER_COMPOSE) $(COMPOSE_CORE) logs -f $(SERVICE)

SERVICE ?= jupyterlab

##@ Build (maintainers)

.PHONY: build
build: ## Build every image locally (uses compose.dev.yml).
	$(DOCKER_COMPOSE) $(COMPOSE_DEV) build

.PHONY: build-base build-spark-base build-spark-master build-spark-worker build-jupyterlab
build-base: ## Build the shared base image.
	docker build \
	    --build-arg BUILD_DATE=$(BUILD_DATE) \
	    --build-arg SCALA_VERSION=$(SCALA_VERSION) \
	    -t $(REGISTRY)/spark-practice-base:$(BASE_TAG) \
	    $(REPO_ROOT)/images/base

build-spark-base: build-base ## Build the Spark base image (depends on base).
	docker build \
	    --build-arg REGISTRY=$(REGISTRY) \
	    --build-arg BASE_TAG=$(BASE_TAG) \
	    --build-arg SPARK_VERSION=$(SPARK_VERSION) \
	    --build-arg HADOOP_VERSION=$(HADOOP_VERSION) \
	    --build-arg BUILD_DATE=$(BUILD_DATE) \
	    -t $(REGISTRY)/spark-practice-spark-base:$(SPARK_TAG) \
	    $(REPO_ROOT)/images/spark-base

build-spark-master: build-spark-base ## Build the Spark master image.
	docker build \
	    --build-arg REGISTRY=$(REGISTRY) \
	    --build-arg SPARK_BASE_TAG=$(SPARK_TAG) \
	    --build-arg BUILD_DATE=$(BUILD_DATE) \
	    -t $(REGISTRY)/spark-practice-spark-master:$(SPARK_TAG) \
	    $(REPO_ROOT)/images/spark-master

build-spark-worker: build-spark-base ## Build the Spark worker image.
	docker build \
	    --build-arg REGISTRY=$(REGISTRY) \
	    --build-arg SPARK_BASE_TAG=$(SPARK_TAG) \
	    --build-arg BUILD_DATE=$(BUILD_DATE) \
	    -t $(REGISTRY)/spark-practice-spark-worker:$(SPARK_TAG) \
	    $(REPO_ROOT)/images/spark-worker

build-jupyterlab: build-base ## Build the JupyterLab image.
	docker build \
	    --build-arg REGISTRY=$(REGISTRY) \
	    --build-arg BASE_TAG=$(BASE_TAG) \
	    --build-arg SPARK_VERSION=$(SPARK_VERSION) \
	    --build-arg SCALA_VERSION=$(SCALA_VERSION) \
	    --build-arg ALMOND_VERSION=$(ALMOND_VERSION) \
	    --build-arg BUILD_DATE=$(BUILD_DATE) \
	    -t $(REGISTRY)/spark-practice-jupyterlab:$(JUPYTERLAB_TAG) \
	    $(REPO_ROOT)/images/jupyterlab

##@ Publish (maintainers)

.PHONY: buildx-init
buildx-init: ## One-time: create a buildx builder for multi-arch.
	docker buildx create --name spark-practice --driver docker-container --use || \
	docker buildx use spark-practice

.PHONY: push
push: buildx-init ## Multi-arch build + push every image. Usage: make push PUSH_TAG=3.5.1-1
	@for img in $(IMAGES); do \
	    echo "==> pushing $(REGISTRY)/spark-practice-$$img:$(PUSH_TAG)"; \
	    docker buildx build \
	        --platform $(PLATFORMS) \
	        --build-arg BUILD_DATE=$(BUILD_DATE) \
	        --build-arg SPARK_VERSION=$(SPARK_VERSION) \
	        --build-arg HADOOP_VERSION=$(HADOOP_VERSION) \
	        --build-arg SCALA_VERSION=$(SCALA_VERSION) \
	        --build-arg ALMOND_VERSION=$(ALMOND_VERSION) \
	        --build-arg REGISTRY=$(REGISTRY) \
	        --build-arg BASE_TAG=$(BASE_TAG) \
	        --build-arg SPARK_BASE_TAG=$(SPARK_TAG) \
	        -t $(REGISTRY)/spark-practice-$$img:$(PUSH_TAG) \
	        -t $(REGISTRY)/spark-practice-$$img:latest \
	        --push \
	        $(REPO_ROOT)/images/$$img; \
	done

##@ Tests

.PHONY: smoke
smoke: ## Run all smoke tests against the running stack.
	bash $(REPO_ROOT)/scripts/smoke-test.sh
