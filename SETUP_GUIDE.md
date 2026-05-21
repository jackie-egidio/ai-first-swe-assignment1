# Quick Reference: Using setup.ps1

## First Time Setup

1. Open PowerShell in the `assignment1` directory
2. Allow script execution (one-time, if needed):
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```
3. Load the setup script:
   ```powershell
   . .\setup.ps1
   ```

## Every Time You Open a New Terminal

Just run:
```powershell
. .\setup.ps1
```

This loads all project variables and helper functions.

## Quick Commands

### Model Training
```powershell
Invoke-ModelTraining          # Train model
Invoke-ModelEvaluation        # Evaluate model
Invoke-ModelExplanation       # Get feature importance
```

### Docker Deployment
```powershell
Build-And-Deploy             # Build, push, and deploy (all-in-one)

# Or step by step:
Build-DockerImage            # Build Docker image
Push-DockerImage             # Push to GCR
Deploy-CloudRun              # Deploy to Cloud Run
```

### Testing
```powershell
Test-API                     # Run 5 smoke tests
Test-API -Count 10           # Run 10 smoke tests
```

### Utilities
```powershell
Show-Status                  # Show deployment status
Get-ServiceUrl               # Get Cloud Run URL (saved to $SERVICE_URL)
Get-AuthToken                # Get fresh token (saved to $TOKEN)
Show-Help                    # Show all available commands
```

## Available Variables

After sourcing the script, these variables are available:

- `$PROJECT_ID` - Your GCP project ID
- `$REGION` - Deployment region (us-east1)
- `$SERVICE_NAME` - Cloud Run service name
- `$IMAGE_NAME` - Docker image name
- `$DATASET` - BigQuery dataset name
- `$MODEL_NAME` - Model name
- `$SERVICE_URL` - Cloud Run service URL (after calling Get-ServiceUrl)
- `$TOKEN` - Auth token (after calling Get-AuthToken)

## Example Workflow

```powershell
# Load environment
. .\setup.ps1

# Train and evaluate model
Invoke-ModelTraining
Invoke-ModelEvaluation
Invoke-ModelExplanation

# Build and deploy API
Build-And-Deploy

# Test the API
Test-API

# Check status
Show-Status
```

## Manual Commands (if needed)

You can still use raw commands with the variables:

```powershell
# Custom BigQuery query
bq query --use_legacy_sql=false "SELECT * FROM $DATASET.$MODEL_NAME LIMIT 1"

# Custom deployment with different settings
gcloud run deploy $SERVICE_NAME --image gcr.io/$PROJECT_ID/$IMAGE_NAME:latest --region $REGION --memory 1Gi

# Manual API test
curl -X POST "$SERVICE_URL/predict" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "@test_request.json"
```
