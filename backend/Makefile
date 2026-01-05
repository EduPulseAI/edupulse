# EduPulse Backend Makefile
# Simplified commands for building and deploying backend services

.PHONY: help build build-push test clean docker-build docker-push

# Configuration
REGISTRY := us-central1-docker.pkg.dev
PROJECT := edupulse-483220
REPOSITORY := edupulse

# Services
SERVICES := event-ingest-service quizzer

help:
	@echo "EduPulse Backend Build Commands"
	@echo "================================"
	@echo ""
	@echo "Maven Commands:"
	@echo "  make build              - Build all services (Maven)"
	@echo "  make test               - Run tests for all services"
	@echo "  make clean              - Clean all services"
	@echo ""
	@echo "Docker Commands (Spring Boot Buildpacks):"
	@echo "  make docker-build       - Build Docker images locally"
	@echo "  make docker-push        - Build and push images to Artifact Registry"
	@echo "  make docker-build-SERVICE - Build specific service (e.g., make docker-build-quizzer)"
	@echo ""
	@echo "Individual Service Commands:"
	@echo "  make build-SERVICE      - Build specific service (e.g., make build-quizzer)"
	@echo "  make test-SERVICE       - Test specific service (e.g., make test-quizzer)"
	@echo ""
	@echo "Available services: $(SERVICES)"

# Build all services with Maven
build:
	@for service in $(SERVICES); do \
		echo "Building $$service..."; \
		cd $$service && ./mvnw clean install -DskipTests || exit 1; \
		cd ..; \
	done

# Run tests for all services
test:
	@for service in $(SERVICES); do \
		echo "Testing $$service..."; \
		cd $$service && ./mvnw test || exit 1; \
		cd ..; \
	done

# Clean all services
clean:
	@for service in $(SERVICES); do \
		echo "Cleaning $$service..."; \
		cd $$service && ./mvnw clean || exit 1; \
		cd ..; \
	done

# Build Docker images locally using Spring Boot buildpacks
docker-build:
	@echo "Building Docker images..."
	@../scripts/docker/build-images.sh

# Build and push Docker images to Artifact Registry
docker-push:
	@echo "Building and pushing Docker images..."
	@../scripts/docker/build-images.sh --push

# Individual service targets
build-event-ingest-service:
	cd event-ingest-service && ./mvnw clean install

build-quizzer:
	cd quizzer && ./mvnw clean install

test-event-ingest-service:
	cd event-ingest-service && ./mvnw test

test-quizzer:
	cd quizzer && ./mvnw test

docker-build-event-ingest-service:
	../scripts/docker/build-images.sh event-ingest-service

docker-build-quizzer:
	../scripts/docker/build-images.sh quizzer

docker-push-event-ingest-service:
	../scripts/docker/build-images.sh --push event-ingest-service

docker-push-quizzer:
	../scripts/docker/build-images.sh --push quizzer

# Quick shortcuts
ei: build-event-ingest-service
q: build-quizzer
