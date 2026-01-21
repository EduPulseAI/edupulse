#!/bin/bash

# -----------------------------------------------------------------------------
# Set GCP Secret Manager Secrets from .env file
# -----------------------------------------------------------------------------
# This script reads values from the root .env file and populates
# GCP Secret Manager secrets for the EduPulse platform.
#
# Usage: ./set-secrets.sh <project-id>
#
# Prerequisites:
# - gcloud CLI installed and authenticated
# - Appropriate IAM permissions (Secret Manager Admin or Secret Manager Secret Version Adder)
# - .env file in the project root with required secret values
# -----------------------------------------------------------------------------

set -e  # Exit on error
set -u  # Exit on undefined variable

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

PROJECT_ID="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Helper Functions
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

# Function to load environment variable from .env file
load_env_var() {
    local var_name="$1"
    local value

    # Extract value from .env file, handling comments and empty lines
    value=$(grep "^${var_name}=" "${ENV_FILE}" 2>/dev/null | cut -d'=' -f2- | sed 's/^["'"'"']\(.*\)["'"'"']$/\1/')

    if [ -z "${value}" ]; then
        log_warning "Environment variable ${var_name} not found in ${ENV_FILE}"
        return 1
    fi

    echo "${value}"
}

# Function to set a GCP secret
set_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="$3"

    if [ -z "${secret_value}" ]; then
        log_warning "Skipping secret ${secret_name} (empty value)"
        return 0
    fi

    log_info "Setting secret: ${secret_name}"

    # Create secret version (secret must already exist from Terraform)
    if echo -n "${secret_value}" | gcloud secrets versions add "${secret_name}" \
        --project="${PROJECT_ID}" \
        --data-file=- > /dev/null 2>&1; then
        log_success "Secret ${secret_name} updated"
    else
        log_error "Failed to set secret ${secret_name}"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

if [ -z "${PROJECT_ID}" ]; then
    log_error "Usage: $0 <project-id>"
    exit 1
fi

if [ ! -f "${ENV_FILE}" ]; then
    log_error "Environment file not found: ${ENV_FILE}"
    log_info "Please create a .env file in the project root with the required secrets"
    exit 1
fi

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    log_error "gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Verify gcloud authentication
if ! gcloud auth list --filter="status:ACTIVE" --format="value(account)" &> /dev/null; then
    log_error "Not authenticated with gcloud. Run: gcloud auth login"
    exit 1
fi

# Set the project
gcloud config set project "${PROJECT_ID}" > /dev/null 2>&1

log_info "Starting secret provisioning for project: ${PROJECT_ID}"
log_info "Reading from: ${ENV_FILE}"
echo ""

# -----------------------------------------------------------------------------
# Map Environment Variables to Secret Names and Set Secrets
# -----------------------------------------------------------------------------

# Counter for success/failure tracking
total_secrets=0
successful_secrets=0
failed_secrets=0

# Kafka Secrets
log_info "=== Kafka Configuration ==="
total_secrets=$((total_secrets + 3))

if kafka_bootstrap_servers=$(load_env_var "KAFKA_BOOTSTRAP_SERVERS"); then
    set_secret "kafka-bootstrap-servers" "${kafka_bootstrap_servers}" "Confluent Kafka bootstrap servers endpoint" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    log_warning "Skipping kafka-bootstrap-servers"
    failed_secrets=$((failed_secrets + 1))
fi

if kafka_api_key=$(load_env_var "KAFKA_API_KEY"); then
    set_secret "kafka-api-key" "${kafka_api_key}" "Confluent Kafka API key for authentication" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    log_warning "Skipping kafka-api-key"
    failed_secrets=$((failed_secrets + 1))
fi

if kafka_api_secret=$(load_env_var "KAFKA_API_SECRET"); then
    set_secret "kafka-api-secret" "${kafka_api_secret}" "Confluent Kafka API secret for authentication" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    log_warning "Skipping kafka-api-secret"
    failed_secrets=$((failed_secrets + 1))
fi

echo ""

# Schema Registry Secrets
log_info "=== Schema Registry Configuration ==="
total_secrets=$((total_secrets + 3))

if schema_registry_url=$(load_env_var "SCHEMA_REGISTRY_URL"); then
    set_secret "schema-registry-url" "${schema_registry_url}" "Confluent Schema Registry URL" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    log_warning "Skipping schema-registry-url"
    failed_secrets=$((failed_secrets + 1))
fi

if schema_registry_api_key=$(load_env_var "SCHEMA_REGISTRY_API_KEY"); then
    set_secret "schema-registry-api-key" "${schema_registry_api_key}" "Confluent Schema Registry API key" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    log_warning "Skipping schema-registry-api-key"
    failed_secrets=$((failed_secrets + 1))
fi

if schema_registry_api_secret=$(load_env_var "SCHEMA_REGISTRY_API_SECRET"); then
    set_secret "schema-registry-api-secret" "${schema_registry_api_secret}" "Confluent Schema Registry API secret" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    log_warning "Skipping schema-registry-api-secret"
    failed_secrets=$((failed_secrets + 1))
fi

echo ""

# PostgreSQL Secrets
log_info "=== PostgreSQL Database Configuration ==="
total_secrets=$((total_secrets + 4))

if postgres_user=$(load_env_var "DATABASE_USER"); then
    set_secret "postgres-user" "${postgres_user}" "PostgreSQL database username for quiz service" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    log_warning "Skipping postgres-user"
    failed_secrets=$((failed_secrets + 1))
fi

if postgres_password=$(load_env_var "DATABASE_PASSWORD"); then
    set_secret "postgres-password" "${postgres_password}" "PostgreSQL database password for quiz service" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    log_warning "Skipping postgres-password"
    failed_secrets=$((failed_secrets + 1))
fi

if postgres_host=$(load_env_var "DATABASE_HOST"); then
    set_secret "postgres-host" "${postgres_host}" "PostgreSQL database host for quiz service" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    log_warning "Skipping postgres-host"
    failed_secrets=$((failed_secrets + 1))
fi

# Extract database name from host or use default
if database_name=$(load_env_var "DATABASE_NAME" 2>/dev/null); then
    set_secret "postgres-database" "${database_name}" "PostgreSQL database name for quiz service" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    # Default database name if not specified
    database_name="edupulse"
    log_info "Using default database name: ${database_name}"
    set_secret "postgres-database" "${database_name}" "PostgreSQL database name for quiz service" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
fi

echo ""

# AI Configuration (Optional)
log_info "=== AI Configuration (Optional) ==="
total_secrets=$((total_secrets + 2))

if gemini_api_key=$(load_env_var "GEMINI_API_KEY" 2>/dev/null); then
    set_secret "gemini-api-key" "${gemini_api_key}" "Google Gemini API key for AI-powered hint generation" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    log_warning "Skipping gemini-api-key (optional, will use Vertex AI if not provided)"
    failed_secrets=$((failed_secrets + 1))
fi

if jwt_signing_key=$(load_env_var "JWT_SIGNING_KEY" 2>/dev/null); then
    set_secret "jwt-signing-key" "${jwt_signing_key}" "JWT signing key for session tokens" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    # Generate a random JWT signing key if not provided
    jwt_signing_key=$(openssl rand -base64 64 | tr -d '\n')
    log_info "Generated random JWT signing key"
    set_secret "jwt-signing-key" "${jwt_signing_key}" "JWT signing key for session tokens" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
fi

echo ""

# Redis Configuration
log_info "=== Redis Memorystore Configuration ==="
total_secrets=$((total_secrets + 3))

if redis_host=$(load_env_var "REDIS_HOST" 2>/dev/null); then
    if [ -n "${redis_host}" ]; then
        set_secret "redis-host" "${redis_host}" "Redis Memorystore host IP for caching" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
    else
        log_warning "Skipping redis-host (empty value - set after terraform apply)"
        failed_secrets=$((failed_secrets + 1))
    fi
else
    log_warning "Skipping redis-host (not found - set after terraform apply)"
    failed_secrets=$((failed_secrets + 1))
fi

if redis_port=$(load_env_var "REDIS_PORT" 2>/dev/null); then
    set_secret "redis-port" "${redis_port}" "Redis Memorystore port" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
else
    # Default Redis port
    redis_port="6379"
    log_info "Using default Redis port: ${redis_port}"
    set_secret "redis-port" "${redis_port}" "Redis Memorystore port" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
fi

if redis_password=$(load_env_var "REDIS_PASSWORD" 2>/dev/null); then
    if [ -n "${redis_password}" ]; then
        set_secret "redis-password" "${redis_password}" "Redis AUTH password for authentication" && successful_secrets=$((successful_secrets + 1)) || failed_secrets=$((failed_secrets + 1))
    else
        log_warning "Skipping redis-password (empty value - set after terraform apply with: terraform output -raw redis_auth_string)"
        failed_secrets=$((failed_secrets + 1))
    fi
else
    log_warning "Skipping redis-password (not found - set after terraform apply with: terraform output -raw redis_auth_string)"
    failed_secrets=$((failed_secrets + 1))
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

echo ""
echo "======================================================================="
log_info "Secret provisioning complete!"
echo "======================================================================="
echo ""
echo "Total secrets processed: ${total_secrets}"
log_success "Successfully set: ${successful_secrets}"
if [ ${failed_secrets} -gt 0 ]; then
    log_error "Failed to set: ${failed_secrets}"
    echo ""
    log_warning "Some secrets were not set. Please verify your .env file and IAM permissions."
    exit 1
else
    echo ""
    log_success "All secrets have been successfully provisioned in GCP Secret Manager"
    log_info "Secrets are now available for Cloud Run services"
fi

echo ""
