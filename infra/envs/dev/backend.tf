# Remote state backend using Google Cloud Storage
# This ensures state is shared across team members and CI/CD pipelines
#
# Prerequisites:
# 1. Create GCS bucket manually or via bootstrap script:
#    gsutil mb -p <PROJECT_ID> -l <REGION> gs://<PROJECT_ID>-terraform-state-dev
#    gsutil versioning set on gs://<PROJECT_ID>-terraform-state-dev
#
# 2. Initialize Terraform:
#    terraform init
#
# To use local backend instead (for testing/development):
# 1. Comment out the entire terraform block below
# 2. Run: terraform init -migrate-state
# 3. State will be stored in terraform.tfstate locally

terraform {
  backend "gcs" {
    # Replace <PROJECT_ID> with your actual GCP project ID
    # bucket = "<PROJECT_ID>-terraform-state-dev"
    bucket = "REPLACE_WITH_PROJECT_ID-terraform-state-dev"
    prefix = "edupulse/dev"

    # Optional: Enable state locking (requires Cloud Storage admin permission)
    # State locking prevents concurrent terraform runs from corrupting state
    # This is enabled by default with GCS backend
  }
}

# Alternative: Local backend (for testing only)
# Uncomment this and comment out the GCS backend above
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
