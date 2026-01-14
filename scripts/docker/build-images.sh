#!/bin/bash

# Build and push Docker images for EduPulse backend services using Spring Boot buildpacks
# Usage:
#   ./build-images.sh [OPTIONS] [SERVICE...]
#
# Options:
#   --push              Push images to Artifact Registry after building
#   --tag TAG           Additional tag to apply (default: latest)
#   --registry REG      Override registry (default: us-central1-docker.pkg.dev)
#   --project PROJ      Override GCP project (default: edupulse-483220)
#   --repository REPO   Override repository (default: edupulse)
#   --help              Show this help message
#
# Services (default: all):
#   event-ingest-service
#   quizzer
#
# Examples:
#   ./build-images.sh                                    # Build all services
#   ./build-images.sh --push                             # Build and push all services
#   ./build-images.sh --push --tag dev quizzer           # Build and push quizzer with 'dev' tag
#   ./build-images.sh --tag v1.0.0 event-ingest-service  # Build event-ingest-service with 'v1.0.0' tag

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
REGISTRY="us-central1-docker.pkg.dev"
PROJECT="edupulse-483220"
REPOSITORY="edupulse"
PUSH=false
ADDITIONAL_TAG="latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/../../backend" && pwd)"

# Available services
ALL_SERVICES=("quiz-service")
SERVICES_TO_BUILD=()

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show help
show_help() {
    sed -n '3,20p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH=true
            shift
            ;;
        --tag)
            ADDITIONAL_TAG="$2"
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --repository)
            REPOSITORY="$2"
            shift 2
            ;;
        --help)
            show_help
            ;;
        -*)
            print_error "Unknown option: $1"
            show_help
            ;;
        *)
            # Check if it's a valid service name
            if [[ " ${ALL_SERVICES[*]} " =~ " $1 " ]]; then
                SERVICES_TO_BUILD+=("$1")
            else
                print_error "Unknown service: $1"
                print_info "Available services: ${ALL_SERVICES[*]}"
                exit 1
            fi
            shift
            ;;
    esac
done

# If no services specified, build all
if [ ${#SERVICES_TO_BUILD[@]} -eq 0 ]; then
    SERVICES_TO_BUILD=("${ALL_SERVICES[@]}")
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Function to extract version from pom.xml
get_version_from_pom() {
    local service_dir=$1
    local pom_file="${service_dir}/pom.xml"

    if [ ! -f "$pom_file" ]; then
        print_error "pom.xml not found in ${service_dir}"
        return 1
    fi

    # Use Maven to get the project version (not parent version)
    if [ -x "${service_dir}/mvnw" ]; then
        cd "$service_dir" && ./mvnw help:evaluate -Dexpression=project.version -q -DforceStdout 2>/dev/null
    else
        print_error "mvnw not found or not executable in ${service_dir}"
        return 1
    fi
}

# Function to build image for a service
build_service_image() {
    local service=$1
    local service_dir="${BACKEND_DIR}/${service}"

    if [ ! -d "$service_dir" ]; then
        print_error "Service directory not found: ${service_dir}"
        return 1
    fi

    print_info "Building ${service}..."

    # Get version from pom.xml
    local version=$(get_version_from_pom "$service_dir")
    if [ -z "$version" ]; then
        print_error "Failed to extract version from pom.xml"
        return 1
    fi

    print_info "Version: ${version}"

    # Build image using Spring Boot buildpacks
    cd "$service_dir"

    # Set image name
    local base_image_name="${REGISTRY}/${PROJECT}/${REPOSITORY}/${service}"
    local versioned_image="${base_image_name}:${version}"

    print_info "Building image: ${versioned_image}"

    # Build the image with Maven
    if ./mvnw -Dimage.name="${versioned_image}" -DskipTests spring-boot:build-image; then
        print_success "Built ${versioned_image}"
    else
        print_error "Failed to build ${service}"
        return 1
    fi

    # Tag with additional tag if different from version
    if [ "$ADDITIONAL_TAG" != "$version" ]; then
        local tagged_image="${base_image_name}:${ADDITIONAL_TAG}"
        print_info "Tagging as ${tagged_image}"
        docker tag "${versioned_image}" "${tagged_image}"
        print_success "Tagged as ${tagged_image}"
    fi

    # Push if requested
    if [ "$PUSH" = true ]; then
        print_info "Pushing ${versioned_image}..."
        if docker push "${versioned_image}"; then
            print_success "Pushed ${versioned_image}"
        else
            print_error "Failed to push ${versioned_image}"
            print_warning "Make sure you're authenticated: gcloud auth configure-docker ${REGISTRY}"
            return 1
        fi

        # Push additional tag
        if [ "$ADDITIONAL_TAG" != "$version" ]; then
            local tagged_image="${base_image_name}:${ADDITIONAL_TAG}"
            print_info "Pushing ${tagged_image}..."
            if docker push "${tagged_image}"; then
                print_success "Pushed ${tagged_image}"
            else
                print_error "Failed to push ${tagged_image}"
                return 1
            fi
        fi
    fi

    print_success "Completed ${service}"
    echo ""
}

# Main execution
print_info "EduPulse Image Builder"
print_info "Registry: ${REGISTRY}/${PROJECT}/${REPOSITORY}"
print_info "Services: ${SERVICES_TO_BUILD[*]}"
print_info "Additional tag: ${ADDITIONAL_TAG}"
print_info "Push: ${PUSH}"
echo ""

# Build each service
failed_services=()
for service in "${SERVICES_TO_BUILD[@]}"; do
    if ! build_service_image "$service"; then
        failed_services+=("$service")
    fi
done

# Summary
echo ""
print_info "Build Summary"
echo "=============="

if [ ${#failed_services[@]} -eq 0 ]; then
    print_success "All services built successfully!"

    if [ "$PUSH" = true ]; then
        print_success "All images pushed to ${REGISTRY}/${PROJECT}/${REPOSITORY}"
    else
        print_info "Images are stored locally. Use --push to push to registry."
        print_info "To push manually, authenticate first:"
        echo "  gcloud auth configure-docker ${REGISTRY}"
    fi
    exit 0
else
    print_error "Failed to build: ${failed_services[*]}"
    exit 1
fi
