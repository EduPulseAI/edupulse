# EduPulse Backend Makefile
# Simplified commands for building and deploying backend services

.PHONY: help build build-push test clean docker-build docker-push

# Configuration
REGISTRY := us-central1-docker.pkg.dev
PROJECT := edupulse-483220
REPOSITORY := edupulse

# Services
SERVICES := quiz-service engagement-service sse-service profile-service auth-service eureka-server api-gateway

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

deploy:
	@echo "Deploying services..."
	@../scripts/gcloud/deploy-service.sh


# quiz service targets
build-quiz-service:
	cd quiz-service && ./mvnw clean install
test-quiz-service:
	cd quiz-service && ./mvnw test
docker-build-quiz-service:
	../scripts/docker/build-images.sh quiz-service

docker-push-quiz-service:
	../scripts/docker/build-images.sh --push quiz-service

# Engagement service targets
build-engagement-service:
	cd engagement-service && ./mvnw clean install
test-engagement-service:
	cd engagement-service && ./mvnw test
docker-build-engagement-service:
	../scripts/docker/build-images.sh engagement-service
docker-push-engagement-service:
	../scripts/docker/build-images.sh --push engagement-service

# SSE service targets
build-sse-service:
	cd sse-service && ./mvnw clean install
test-sse-service:
	cd sse-service && ./mvnw test
docker-build-sse-service:
	../scripts/docker/build-images.sh sse-service
docker-push-sse-service:
	../scripts/docker/build-images.sh --push sse-service

# Profile service targets
build-profile-service:
	cd profile-service && ./mvnw clean install
test-profile-service:
	cd profile-service && ./mvnw test
docker-build-profile-service:
	../scripts/docker/build-images.sh profile-service
docker-push-profile-service:
	../scripts/docker/build-images.sh --push profile-service


# Auth service targets
build-auth-service:
	cd auth-service && ./mvnw clean install
test-auth-service:
	cd auth-service && ./mvnw test
docker-build-auth-service:
	../scripts/docker/build-images.sh auth-service
docker-push-auth-service:
	../scripts/docker/build-images.sh --push auth-service

# Eureka server targets
docker-build-eureka-server:
	../scripts/docker/build-images.sh eureka-server
docker-push-eureka-server:
	../scripts/docker/build-images.sh --push eureka-server

# API Gateway targets
docker-build-api-gateway:
	../scripts/docker/build-images.sh api-gateway
docker-push-api-gateway:
	../scripts/docker/build-images.sh --push api-gateway


# Quick shortcuts
quiz: docker-push-quiz-service
engagement: docker-push-engagement-service
sse: docker-push-sse-service
profile: docker-push-profile-service
auth: docker-push-auth-service
eureka: docker-push-eureka-server
apigw: docker-push-api-gateway
