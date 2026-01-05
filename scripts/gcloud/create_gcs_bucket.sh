
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
# Script directory and project root
# -----------------------------------------------------------------------------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

log_header "EduPulse GCS Bucket Creator "

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


# -----------------------------------------------------------------------------
# Validate required tools
# -----------------------------------------------------------------------------
log_info "Validating required tools..."

command -v gcloud >/dev/null 2>&1 || {
    log_error "gcloud CLI is not installed. Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
}


# Create GCS bucket:
gsutil mb -p $PROJECT_ID -l $REGION gs://$PROJECT_ID-terraform-state-dev
gsutil versioning set on gs://$PROJECT_ID-terraform-state-dev
