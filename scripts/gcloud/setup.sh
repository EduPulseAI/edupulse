set -xa; source .env; set +a;

# Login without browser launch (key for WSL)
gcloud auth login --no-launch-browser

gcloud config set project "$PROJECT_ID"
gcloud config set run/region "$REGION"
