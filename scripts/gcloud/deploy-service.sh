#!/bin/bash

# -----------------------------------------------------------------------------
# Redeploy Cloud Run Service
# -----------------------------------------------------------------------------
# Forces Cloud Run to pull the latest image and create a new revision.
# Use this after pushing an updated Docker image to redeploy a service
# that Terraform won't detect as changed.
#
# Usage: ./deploy-service.sh <service-name> [options]
#
# Options:
#   --region <region>   GCP region (default: us-central1)
#   --project <id>      GCP project ID (default: edupulse-483220)
#   --tag <tag>         Image tag to deploy (default: current image tag)
#   --dry-run           Show commands without executing
#
# Examples:
#   ./deploy-service.sh engagement-service
#   ./deploy-service.sh quiz-service --region us-east1
#   ./deploy-service.sh engagement-service --tag 0.0.2-SNAPSHOT
# -----------------------------------------------------------------------------

set -e
set -u

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

DEFAULT_REGION="us-central1"
DEFAULT_PROJECT="edupulse-483220"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

show_usage() {
    cat << EOF
Usage: $0 <service-name> [options]

Redeploys a Cloud Run service by forcing a new revision.

Options:
  --region <region>   GCP region (default: ${DEFAULT_REGION})
  --project <id>      GCP project ID (default: ${DEFAULT_PROJECT})
  --tag <tag>         Image tag to deploy (overrides current tag)
  --dry-run           Show commands without executing
  -h, --help          Show this help

Examples:
  $0 engagement-service
  $0 quiz-service --tag 0.0.2-SNAPSHOT
EOF
}

# -----------------------------------------------------------------------------
# Parse Arguments
# -----------------------------------------------------------------------------

SERVICE_NAME=""
REGION="${DEFAULT_REGION}"
PROJECT_ID="${DEFAULT_PROJECT}"
IMAGE_TAG=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --region)   REGION="$2"; shift 2 ;;
        --project)  PROJECT_ID="$2"; shift 2 ;;
        --tag)      IMAGE_TAG="$2"; shift 2 ;;
        --dry-run)  DRY_RUN=true; shift ;;
        -h|--help)  show_usage; exit 0 ;;
        -*)         log_error "Unknown option: $1"; show_usage; exit 1 ;;
        *)
            if [ -z "$SERVICE_NAME" ]; then
                SERVICE_NAME="$1"
            else
                log_error "Unexpected argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$SERVICE_NAME" ]; then
    log_error "Service name is required"
    show_usage
    exit 1
fi

# -----------------------------------------------------------------------------
# Validate Prerequisites
# -----------------------------------------------------------------------------

if ! command -v gcloud &> /dev/null; then
    log_error "gcloud CLI not found"
    exit 1
fi

if ! gcloud auth list --filter="status:ACTIVE" --format="value(account)" &> /dev/null; then
    log_error "Not authenticated. Run: gcloud auth login"
    exit 1
fi

# -----------------------------------------------------------------------------
# Get Current Service Info
# -----------------------------------------------------------------------------

log_info "Fetching current service configuration..."

CURRENT_IMAGE=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(spec.template.spec.containers[0].image)" 2>/dev/null)

if [ -z "$CURRENT_IMAGE" ]; then
    log_error "Service '${SERVICE_NAME}' not found in region '${REGION}'"
    exit 1
fi

# If tag override provided, replace the tag in the image URI
if [ -n "$IMAGE_TAG" ]; then
    IMAGE_BASE="${CURRENT_IMAGE%:*}"
    DEPLOY_IMAGE="${IMAGE_BASE}:${IMAGE_TAG}"
else
    DEPLOY_IMAGE="$CURRENT_IMAGE"
fi

echo ""
log_info "Service:       ${SERVICE_NAME}"
log_info "Region:        ${REGION}"
log_info "Project:       ${PROJECT_ID}"
log_info "Current image: ${CURRENT_IMAGE}"
log_info "Deploy image:  ${DEPLOY_IMAGE}"
echo ""

# -----------------------------------------------------------------------------
# Redeploy Service
# -----------------------------------------------------------------------------

log_info "Redeploying service..."

# Use gcloud run deploy with --no-traffic=false to force new revision
# The key is using the same image URI - Cloud Run will pull fresh
DEPLOY_CMD="gcloud run deploy ${SERVICE_NAME} \
    --image=${DEPLOY_IMAGE} \
    --region=${REGION} \
    --project=${PROJECT_ID} \
    --quiet"

if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN - would execute:"
    echo "  $DEPLOY_CMD"
else
    if $DEPLOY_CMD; then
        log_success "Service redeployed successfully"
    else
        log_error "Deployment failed"
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Verify Deployment
# -----------------------------------------------------------------------------

if [ "$DRY_RUN" = false ]; then
    echo ""
    log_info "Verifying deployment..."

    # Get service URL and latest revision
    SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(status.url)")

    LATEST_REVISION=$(gcloud run services describe "$SERVICE_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(status.latestReadyRevisionName)")

    log_success "URL: ${SERVICE_URL}"
    log_success "Revision: ${LATEST_REVISION}"

    echo ""
    log_info "View logs: gcloud run services logs read ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID} --limit=50"
fi
