# EduPulse Backend Build Guide

This guide explains how to build Docker images for EduPulse backend services using Spring Boot's Cloud Native Buildpacks.

## Prerequisites

- **Java 21** - Required for building services
- **Maven** - Included via Maven wrapper (`mvnw`)
- **Docker** - Must be running for image builds
- **gcloud CLI** - Required for pushing to Google Artifact Registry

## Quick Start

### Build All Services (Maven Only)

```bash
cd backend
make build
```

### Build Docker Images Locally

```bash
cd backend
make docker-build
```

### Build and Push to Artifact Registry

```bash
cd backend

# Authenticate with Google Artifact Registry first
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and push
make docker-push
```

## Building Individual Services

### Using Make

```bash
# Build with Maven
make build-quizzer
make build-event-ingest-service

# Build Docker image
make docker-build-quizzer
make docker-build-event-ingest-service

# Build and push Docker image
make docker-push-quizzer
make docker-push-event-ingest-service
```

### Using Maven Directly

```bash
# Build service
cd quizzer
./mvnw clean install

# Build Docker image
./mvnw spring-boot:build-image

# The image name is configured in pom.xml:
# us-central1-docker.pkg.dev/edupulse-483220/edupulse/quizzer:0.0.2-SNAPSHOT
```

## Using the Build Script

The `scripts/docker/build-images.sh` script provides more control:

```bash
# Build all services
./scripts/docker/build-images.sh

# Build specific service
./scripts/docker/build-images.sh quizzer

# Build and push
./scripts/docker/build-images.sh --push

# Build with custom tag
./scripts/docker/build-images.sh --tag dev quizzer

# Build and push with custom tag
./scripts/docker/build-images.sh --push --tag v1.0.0

# Get help
./scripts/docker/build-images.sh --help
```

## Image Configuration

Images are configured in each service's `pom.xml`:

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
                </image>
            </configuration>
        </plugin>
    </plugins>
</build>
```

## Image Naming Convention

Images follow this pattern:
```
{registry}/{project}/{repository}/{service}:{version}
```

**Example:**
```
us-central1-docker.pkg.dev/edupulse-483220/edupulse/quizzer:0.0.2-SNAPSHOT
us-central1-docker.pkg.dev/edupulse-483220/edupulse/event-ingest-service:0.0.1-SNAPSHOT
```

## Customizing the Build

### Change the Registry

Edit the properties in `pom.xml`:

```xml
<properties>
    <docker.registry>your-registry.example.com</docker.registry>
    <docker.project>your-project</docker.project>
    <docker.repository>your-repo</docker.repository>
</properties>
```

Or override via command line:

```bash
./scripts/docker/build-images.sh --registry gcr.io --project my-project --repository my-repo
```

### Customize Buildpack Behavior

Add environment variables in the `pom.xml` configuration:

```xml
<configuration>
    <image>
        <name>${image.name}</name>
        <env>
            <BP_JVM_VERSION>21</BP_JVM_VERSION>
            <BP_JVM_JLINK_ENABLED>true</BP_JVM_JLINK_ENABLED>
            <BPL_JVM_THREAD_COUNT>50</BPL_JVM_THREAD_COUNT>
        </env>
    </image>
</configuration>
```

[See Paketo Buildpacks documentation for all options](https://paketo.io/docs/reference/java-reference/)

## Pushing to Google Artifact Registry

### One-time Setup

```bash
# Configure Docker to use gcloud for authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Verify access
gcloud artifacts repositories describe edupulse \
  --project=edupulse-483220 \
  --location=us-central1
```

### Push Images

```bash
# Using Make
make docker-push

# Using script
./scripts/docker/build-images.sh --push

# Manual push (after building)
docker push us-central1-docker.pkg.dev/edupulse-483220/edupulse/quizzer:0.0.2-SNAPSHOT
docker push us-central1-docker.pkg.dev/edupulse-483220/edupulse/event-ingest-service:0.0.1-SNAPSHOT
```

## Testing

```bash
# Run tests for all services
make test

# Test specific service
make test-quizzer
make test-event-ingest-service

# Or use Maven directly
cd quizzer
./mvnw test
```

## Troubleshooting

### Docker is not running

```
Error: Cannot connect to the Docker daemon
```

**Solution:** Start Docker Desktop or Docker daemon

### Authentication failed when pushing

```
Error: unauthorized: authentication required
```

**Solution:** Authenticate with gcloud
```bash
gcloud auth login
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### Build fails with "Cannot find parent POM"

```
Error: Could not find artifact xyz.catuns.spring:base-starter-parent
```

**Solution:** Ensure GitHub packages authentication is configured in `~/.m2/settings.xml`

### Out of memory during image build

**Solution:** Increase Docker memory limit in Docker Desktop settings (Preferences → Resources → Memory)

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Push Images

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up JDK 21
        uses: actions/setup-java@v3
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker us-central1-docker.pkg.dev

      - name: Build and Push Images
        run: |
          cd backend
          make docker-push
```

## Cloud Build Integration

See `infra/cloudbuild/` for Cloud Build configuration examples.

## Related Documentation

- [Docker Build Setup](../docs/DOCKER_BUILD_SETUP.md) - Quick start guide
- [Spring Boot Build Image Documentation](https://docs.spring.io/spring-boot/docs/current/maven-plugin/reference/htmlsingle/#build-image)
- [Paketo Buildpacks](https://paketo.io/)
- [Google Artifact Registry](https://cloud.google.com/artifact-registry/docs)
