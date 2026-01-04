# https://docs.cloud.google.com/sdk/docs/install-sdk#deb

sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates gnupg curl

# Import the Google Cloud public key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

# Add the gcloud CLI distribution URI as a package source
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Update and install the gcloud CLI
sudo apt-get update && sudo apt-get install google-cloud-cli -y
