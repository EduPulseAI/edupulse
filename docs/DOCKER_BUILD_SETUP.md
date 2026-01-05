# Docker Build Setup - Spring Boot Buildpacks

## What's Been Configured

Your EduPulse backend services are now configured to use **Spring Boot's Cloud Native Buildpacks** (`spring-boot:build-image`) for building Docker images. This eliminates the need for Dockerfiles and provides production-ready, optimized container images.

## Changes Made

### 1. Updated POM Files

Both `backend/event-ingest-service/pom.xml` and `backend/quizzer/pom.xml` now include:

```xml
<properties>
    <docker.registry>us-central1-docker.pkg.dev</docker.registry>
    <docker.project>edupulse-483220</docker.project>
    <docker.repository>edupulse</docker.repository>
    <image.name>${docker.registry}/${docker.project}/${docker.repository}/${project.artifactId}:${project.version}</image.name>
</properties>

<build>
    <plugins>
        <plugin>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-maven-plugin</artifactId>
            <configuration>
                <image>
                    <name>${image.name}</name>
                    <env>
                        <BP_JVM_VERSION>21</BP_JVM_VERSION>
                    </env>
                    <publish>false</publish>
                </image>
            </configuration>
        </plugin>
    </plugins>
</build>
```

### 2. Created Build Script

**Location:** `scripts/docker/build-images.sh`

A comprehensive script that:
- Builds Docker images for all or specific services
- Automatically tags images with version from pom.xml
- Optionally pushes to Google Artifact Registry
- Provides colored output and error handling

### 3. Created Makefile

**Location:** `backend/Makefile`

Simplifies common build tasks with easy-to-remember commands.

### 4. Created Documentation

**Location:** `backend/BUILD.md`

Complete guide for building, testing, and deploying images.

## How to Use

### Quick Commands (Using Make)

```bash
cd backend

# Build all services (Maven only, no Docker)
make build

# Build Docker images for all services
make docker-build

# Build and push to Artifact Registry
make docker-push

# Build specific service
make docker-build-quizzer
make docker-build-event-ingest-service

# Run tests
make test

# Show all available commands
make help
```

### Using the Build Script Directly

```bash
# Build all services
./scripts/docker/build-images.sh

# Build specific service
./scripts/docker/build-images.sh quizzer

# Build and push
./scripts/docker/build-images.sh --push

# Build with custom tag
./scripts/docker/build-images.sh --tag dev

# Get help
./scripts/docker/build-images.sh --help
```

### Using Maven Directly

```bash
cd backend/quizzer

# Build Docker image
./mvnw spring-boot:build-image

# The image will be named:
# us-central1-docker.pkg.dev/edupulse-483220/edupulse/quizzer:0.0.2-SNAPSHOT
```

## Image Names

Images are automatically named according to your Terraform configuration:

- **event-ingest-service**: `us-central1-docker.pkg.dev/edupulse-483220/edupulse/event-ingest-service:0.0.1-SNAPSHOT`
- **quizzer**: `us-central1-docker.pkg.dev/edupulse-483220/edupulse/quizzer:0.0.2-SNAPSHOT`

Each image is also tagged as `:latest` by default.

## Pushing to Google Artifact Registry

### One-time Authentication

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### Push Images

```bash
# Option 1: Using Make
cd backend
make docker-push

# Option 2: Using script
./scripts/docker/build-images.sh --push

# Option 3: Manual
docker push us-central1-docker.pkg.dev/edupulse-483220/edupulse/quizzer:0.0.2-SNAPSHOT
```

## Benefits of Spring Boot Buildpacks

1. **No Dockerfile needed** - Maintained by Paketo Buildpacks team
2. **Optimized layers** - Better caching and smaller image updates
3. **Security** - Regularly updated base images with CVE fixes
4. **Production-ready** - Memory calculator, APM support, etc.
5. **Consistent** - Same build process across all services

## Integration with Terraform

Your Terraform configuration (`infra/envs/dev/terraform.tfvars`) expects images at:

```
us-central1-docker.pkg.dev/edupulse-483220/edupulse/{service}:latest
```

The build system is now aligned with this configuration. After building and pushing:

```bash
# Build and push all images
cd backend
make docker-push

# Deploy with Terraform
cd ../infra/envs/dev
terraform apply
```

## Next Steps

1. **Build your images:**
   ```bash
   cd backend
   make docker-build
   ```

2. **Authenticate with GCP:**
   ```bash
   gcloud auth configure-docker us-central1-docker.pkg.dev
   ```

3. **Push to registry:**
   ```bash
   make docker-push
   ```

4. **Deploy with Terraform:**
   ```bash
   cd ../infra/envs/dev
   terraform apply tfplan
   ```

## Troubleshooting

See [backend/BUILD.md](../backend/BUILD.md) for detailed troubleshooting guide.

## Additional Resources

- [Spring Boot Build Image Documentation](https://docs.spring.io/spring-boot/docs/current/maven-plugin/reference/htmlsingle/#build-image)
- [Paketo Buildpacks](https://paketo.io/)
- [Backend Build Guide](../backend/BUILD.md) - Complete build guide
