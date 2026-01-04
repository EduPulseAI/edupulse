#!/bin/bash

################################################################################
# EduPulse Terraform Deployment Script
#
# This script automates the deployment of EduPulse infrastructure to GCP
# using Terraform with environment-specific configurations.
#
# Usage:
#   ./deploy.sh [OPTIONS]
#
# Options:
#   --env ENV              Environment (dev|prod) - default: dev
#   --build-images         Build and push container images before deployment
#   --skip-terraform       Skip Terraform apply (only build images)
#   --auto-approve         Auto-approve Terraform apply (no prompt)
#   --destroy              Destroy infrastructure instead of creating
#   --init-only            Only run terraform init
#   --plan-only            Only run terraform plan
#   --validate-secrets     Validate all required secrets exist
#   --help                 Show this help message
#
# Prerequisites:
#   - .env file with required environment variables
#   - gcloud CLI authenticated
#   - Terraform installed
#   - Docker installed (if --build-images is used)
#
################################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# -----------------------------------------------------------------------------
# Colors for output
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Logging functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Default values
# -----------------------------------------------------------------------------
ENV="dev"
BUILD_IMAGES=false
SKIP_TERRAFORM=false
AUTO_APPROVE=false
DESTROY=false
INIT_ONLY=false
PLAN_ONLY=false
VALIDATE_SECRETS=false

# -----------------------------------------------------------------------------
# Parse command line arguments
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV="$2"
            shift 2
            ;;
        --build-images)
            BUILD_IMAGES=true
            shift
            ;;
        --skip-terraform)
            SKIP_TERRAFORM=true
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --destroy)
            DESTROY=true
            shift
            ;;
        --init-only)
            INIT_ONLY=true
            shift
            ;;
        --plan-only)
            PLAN_ONLY=true
            shift
            ;;
        --validate-secrets)
            VALIDATE_SECRETS=true
            shift
            ;;
        --help)
            grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Validate environment
# -----------------------------------------------------------------------------
if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
    log_error "Invalid environment: $ENV. Must be 'dev' or 'prod'"
    exit 1
fi

# -----------------------------------------------------------------------------
# Script directory and project root
# -----------------------------------------------------------------------------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

log_header "EduPulse Terraform Deployment - Environment: $ENV"

# -----------------------------------------------------------------------------
# Load environment variables from .env file
# -----------------------------------------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
    log_error ".env file not found at: $ENV_FILE"
    log_info "Please create a .env file based on .env.example"
    exit 1
fi

log_info "Loading environment variables from .env file..."
set -a  # Export all variables
source "$ENV_FILE"
set +a

# -----------------------------------------------------------------------------
# Validate required environment variables
# -----------------------------------------------------------------------------
log_info "Validating required environment variables..."

REQUIRED_VARS=(
    "PROJECT_ID"
    "REGION"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        MISSING_VARS+=("$var")
    fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
    log_error "Missing required environment variables in .env file:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    exit 1
fi

log_success "All required environment variables are set"
log_info "PROJECT_ID: $PROJECT_ID"
log_info "REGION: $REGION"
log_info "ENVIRONMENT: $ENV"

# -----------------------------------------------------------------------------
# Validate required tools
# -----------------------------------------------------------------------------
log_info "Validating required tools..."

command -v gcloud >/dev/null 2>&1 || {
    log_error "gcloud CLI is not installed. Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
}

command -v terraform >/dev/null 2>&1 || {
    log_error "Terraform is not installed. Install from: https://developer.hashicorp.com/terraform/downloads"
    exit 1
}

if [[ "$BUILD_IMAGES" == true ]]; then
    command -v docker >/dev/null 2>&1 || {
        log_error "Docker is not installed but --build-images was specified"
        exit 1
    }
fi

log_success "All required tools are available"

# -----------------------------------------------------------------------------
# Set GCP project context
# -----------------------------------------------------------------------------
log_info "Setting GCP project context..."
gcloud config set project "$PROJECT_ID" --quiet

CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [[ "$CURRENT_PROJECT" != "$PROJECT_ID" ]]; then
    log_error "Failed to set GCP project to $PROJECT_ID"
    exit 1
fi

log_success "GCP project set to: $PROJECT_ID"

# -----------------------------------------------------------------------------
# Validate secrets if requested
# -----------------------------------------------------------------------------
if [[ "$VALIDATE_SECRETS" == true ]]; then
    log_header "Validating Secret Manager Secrets"

    REQUIRED_SECRETS=(
        "kafka-bootstrap-servers"
        "kafka-api-key"
        "kafka-api-secret"
        "schema-registry-url"
        "schema-registry-api-key"
        "schema-registry-api-secret"
        "gemini-api-key"
        "jwt-signing-key"
        "postgres-user"
        "postgres-password"
        "postgres-database"
    )

    MISSING_SECRETS=()
    for secret in "${REQUIRED_SECRETS[@]}"; do
        if ! gcloud secrets describe "$secret" --project="$PROJECT_ID" >/dev/null 2>&1; then
            MISSING_SECRETS+=("$secret")
        fi
    done

    if [[ ${#MISSING_SECRETS[@]} -gt 0 ]]; then
        log_warning "Missing secrets (will be created by Terraform):"
        for secret in "${MISSING_SECRETS[@]}"; do
            echo "  - $secret"
        done
        log_info "You will need to add secret values manually after Terraform creates the placeholders"
    else
        log_success "All required secrets exist"
    fi
fi

# -----------------------------------------------------------------------------
# Terraform operations
# -----------------------------------------------------------------------------
TERRAFORM_DIR="$PROJECT_ROOT/infra/envs/$ENV"

if [[ ! -d "$TERRAFORM_DIR" ]]; then
    log_error "Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi

log_info "Changing to Terraform directory: $TERRAFORM_DIR"
cd "$TERRAFORM_DIR"

# Terraform init
log_header "Terraform Init"
log_info "Initializing Terraform..."

if terraform init -upgrade; then
    log_success "Terraform initialized successfully"
else
    log_error "Terraform init failed"
    exit 1
fi

if [[ "$INIT_ONLY" == true ]]; then
    log_success "Init-only mode: Terraform initialized. Exiting."
    exit 0
fi

# Terraform validate
log_info "Validating Terraform configuration..."
if terraform validate; then
    log_success "Terraform configuration is valid"
else
    log_error "Terraform validation failed"
    exit 1
fi

# Terraform format
log_info "Formatting Terraform files..."
terraform fmt -recursive

# Terraform plan
log_header "Terraform Plan"
log_info "Creating Terraform plan..."

PLAN_FILE="tfplan-$(date +%Y%m%d-%H%M%S)"
PLAN_ARGS="-out=$PLAN_FILE"

if [[ "$DESTROY" == true ]]; then
    PLAN_ARGS="$PLAN_ARGS -destroy"
    log_warning "DESTROY mode: Planning to destroy all infrastructure"
fi

if terraform plan $PLAN_ARGS; then
    log_success "Terraform plan created: $PLAN_FILE"
else
    log_error "Terraform plan failed"
    exit 1
fi

if [[ "$PLAN_ONLY" == true ]]; then
    log_success "Plan-only mode: Terraform plan created. Exiting."
    log_info "To apply this plan, run: terraform apply $PLAN_FILE"
    exit 0
fi

if [[ "$SKIP_TERRAFORM" == true ]]; then
    log_info "Skipping Terraform apply (--skip-terraform specified)"
else
    # Terraform apply
    log_header "Terraform Apply"

    if [[ "$AUTO_APPROVE" == true ]]; then
        log_info "Applying Terraform plan (auto-approved)..."
        APPLY_ARGS="-auto-approve"
    else
        log_info "Applying Terraform plan..."
        echo ""
        echo -e "${YELLOW}Review the plan above. Do you want to proceed?${NC}"
        read -p "Type 'yes' to continue: " -r
        if [[ ! $REPLY =~ ^yes$ ]]; then
            log_info "Terraform apply cancelled by user"
            exit 0
        fi
        APPLY_ARGS=""
    fi

    if terraform apply $APPLY_ARGS "$PLAN_FILE"; then
        log_success "Terraform apply completed successfully"
    else
        log_error "Terraform apply failed"
        exit 1
    fi

    # Clean up plan file
    rm -f "$PLAN_FILE"

    # Show outputs
    log_header "Terraform Outputs"
    terraform output
fi

# -----------------------------------------------------------------------------
# Build and push Docker images
# -----------------------------------------------------------------------------
if [[ "$BUILD_IMAGES" == true ]]; then
    log_header "Building and Pushing Docker Images"

    # Get Artifact Registry URL from Terraform output
    ARTIFACT_REGISTRY_URL=$(terraform output -raw artifact_registry_repository_url 2>/dev/null || echo "")

    if [[ -z "$ARTIFACT_REGISTRY_URL" ]]; then
        log_error "Could not retrieve Artifact Registry URL from Terraform outputs"
        exit 1
    fi

    log_info "Artifact Registry: $ARTIFACT_REGISTRY_URL"

    # Authenticate Docker
    log_info "Authenticating Docker with Artifact Registry..."
    DOCKER_HOSTNAME=$(echo "$ARTIFACT_REGISTRY_URL" | cut -d'/' -f1)
    gcloud auth configure-docker "$DOCKER_HOSTNAME" --quiet

    # List of services to build
    SERVICES=(
        "event-ingest-service"
        "quizzer"
        "bandit-engine"
        "tip-service"
        "content-adapter"
        "realtime-gateway"
    )

    BACKEND_DIR="$PROJECT_ROOT/backend"

    for service in "${SERVICES[@]}"; do
        SERVICE_DIR="$BACKEND_DIR/$service"

        if [[ ! -d "$SERVICE_DIR" ]]; then
            log_warning "Service directory not found: $SERVICE_DIR - Skipping"
            continue
        fi

        if [[ ! -f "$SERVICE_DIR/Dockerfile" ]]; then
            log_warning "Dockerfile not found in $SERVICE_DIR - Skipping"
            continue
        fi

        log_info "Building $service..."

        IMAGE_TAG="${IMAGE_TAG:-latest}"
        IMAGE_URI="$ARTIFACT_REGISTRY_URL/$service:$IMAGE_TAG"

        if docker build -t "$IMAGE_URI" "$SERVICE_DIR"; then
            log_success "Built $service"

            log_info "Pushing $service to Artifact Registry..."
            if docker push "$IMAGE_URI"; then
                log_success "Pushed $service"
            else
                log_error "Failed to push $service"
                exit 1
            fi
        else
            log_error "Failed to build $service"
            exit 1
        fi
    done

    log_success "All images built and pushed successfully"

    # Update Cloud Run services with new images
    if [[ "$SKIP_TERRAFORM" == false ]]; then
        log_info "Triggering Cloud Run service updates with new images..."
        log_info "Run 'terraform apply' again to deploy new image revisions"
    fi
fi

# -----------------------------------------------------------------------------
# Final summary
# -----------------------------------------------------------------------------
log_header "Deployment Summary"

if [[ "$DESTROY" == true ]]; then
    log_success "Infrastructure destruction completed"
else
    log_success "Deployment completed successfully!"

    echo ""
    log_info "Next steps:"
    echo "  1. Set secret values in Secret Manager (if not already done):"
    echo "     gcloud secrets versions add kafka-bootstrap-servers --data-file=- <<< 'YOUR_VALUE'"
    echo ""
    echo "  2. Verify Cloud Run services are healthy:"
    echo "     gcloud run services list --project=$PROJECT_ID --region=$REGION"
    echo ""
    echo "  3. Get service URLs:"
    echo "     terraform output cloud_run_service_urls"
    echo ""
    echo "  4. Test service health:"
    echo "     curl \$(terraform output -raw cloud_run_service_urls | jq -r '.\"event-ingest-service\"')/actuator/health"
    echo ""
    echo "  5. Deploy Confluent Flink jobs (see docs/DEPLOYMENT.md)"
    echo ""
fi

log_success "Script completed successfully"
exit 0
