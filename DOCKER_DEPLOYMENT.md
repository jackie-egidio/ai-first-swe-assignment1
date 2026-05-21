# Docker Deployment Guide

Since the Cloud Build permissions haven't been configured yet, you can deploy using a pre-built Docker image instead.

## Prerequisites

Make sure Docker Desktop is installed and running on your Windows machine.

## Steps

### 1. Build the Docker Image Locally

From the `assignment1` directory:

```powershell
# Set variables
$PROJECT_ID = "YOUR_PROJECT_ID"
$IMAGE_NAME = "your-inference-api"
$TAG = "latest"

# Build the image
docker build -t gcr.io/$PROJECT_ID/$IMAGE_NAME:$TAG .
```

### 2. Configure Docker for GCR

Authenticate Docker to push to Google Container Registry:

```powershell
gcloud auth configure-docker
```

### 3. Push Image to GCR

```powershell
docker push gcr.io/$PROJECT_ID/$IMAGE_NAME:$TAG
```

### 4. Deploy to Cloud Run

Deploy the pre-built image:

```powershell
gcloud run deploy jegidio-inference-api `
  --image gcr.io/$PROJECT_ID/$IMAGE_NAME:$TAG `
  --region us-east4 `
  --platform managed `
  --min-instances 0 `
  --memory 512Mi `
  --timeout 30 `
  --no-allow-unauthenticated
```

### 5. Test the Deployment

Same testing process as before:

```powershell
# Get service URL
$SERVICE_URL = gcloud run services describe your-inference-api --region us-east4 --format="value(status.url)"

# Get auth token
$TOKEN = gcloud auth print-identity-token

# Test with 5 requests
1..5 | ForEach-Object {
  Write-Host "`n--- Request $_ ---"
  curl -X POST "$SERVICE_URL/predict" `
    -H "Authorization: Bearer $TOKEN" `
    -H "Content-Type: application/json" `
    -d "@test_request.json"
}
```

## All-in-One Deployment Script

```powershell
# Set variables
$PROJECT_ID = "YOUR_PROJECT_ID"
$IMAGE_NAME = "your-inference-api"
$REGION = "us-east4"

# Build and push
docker build -t gcr.io/$PROJECT_ID/$IMAGE_NAME:latest .
docker push gcr.io/$PROJECT_ID/$IMAGE_NAME:latest

# Deploy
gcloud run deploy your-inference-api `
  --image gcr.io/$PROJECT_ID/$IMAGE_NAME:latest `
  --region $REGION `
  --platform managed `
  --min-instances 0 `
  --memory 512Mi `
  --timeout 30 `
  --no-allow-unauthenticated

# Get URL and test
$SERVICE_URL = gcloud run services describe your-inference-api --region $REGION --format="value(status.url)"
$TOKEN = gcloud auth print-identity-token

Write-Host "`nService deployed at: $SERVICE_URL"
Write-Host "`nRunning smoke tests..."

1..5 | ForEach-Object {
  Write-Host "`n--- Request $_ ---"
  curl -X POST "$SERVICE_URL/predict" `
    -H "Authorization: Bearer $TOKEN" `
    -H "Content-Type: application/json" `
    -d "@test_request.json"
}
```

## Troubleshooting

**Docker not found**
- Install Docker Desktop for Windows
- Make sure it's running

**Permission denied pushing to GCR**
- Run: `gcloud auth configure-docker`
- Ensure you have `storage.buckets.create` permission on the project

**Image builds but push fails**
- Check you're authenticated: `gcloud auth list`
- Verify project: `gcloud config get-value project`

**Cloud Run deployment fails**
- Check you have `run.admin` or `run.deployer` role
- Verify the image was pushed: `gcloud container images list`
