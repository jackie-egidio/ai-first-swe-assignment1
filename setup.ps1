# Assignment 1 - PowerShell Helper Script
# Source this script to set up your environment variables and helper functions
# Usage: . .\setup.ps1

# Project Configuration
$env:PROJECT_ID = "YOUR_PROJECT_ID"
$env:REGION = "us-east4"
$env:SERVICE_NAME = "your-inference-api"
$env:IMAGE_NAME = "your-inference-api"
$env:DATASET = "your_dataset_ml"
$env:MODEL_NAME = "default_risk_v1"

# Set as global variables for easy access
$global:PROJECT_ID = $env:PROJECT_ID
$global:REGION = $env:REGION
$global:SERVICE_NAME = $env:SERVICE_NAME
$global:IMAGE_NAME = $env:IMAGE_NAME
$global:DATASET = $env:DATASET
$global:MODEL_NAME = $env:MODEL_NAME

# Set gcloud project
gcloud config set project $PROJECT_ID 2>$null

Write-Host "Environment configured:" -ForegroundColor Green
Write-Host "   Project ID:    $PROJECT_ID" -ForegroundColor Cyan
Write-Host "   Region:        $REGION" -ForegroundColor Cyan
Write-Host "   Service:       $SERVICE_NAME" -ForegroundColor Cyan
Write-Host "   Dataset:       $DATASET" -ForegroundColor Cyan
Write-Host ""

# Helper Functions

function Get-ServiceUrl {
    $url = gcloud run services describe $SERVICE_NAME --region $REGION --format="value(status.url)" 2>$null
    if ($url) {
        $global:SERVICE_URL = $url
        return $url
    } else {
        Write-Host "Service not deployed yet or not found" -ForegroundColor Yellow
        return $null
    }
}

function Get-AuthToken {
    $token = gcloud auth print-identity-token 2>$null
    if ($token) {
        $global:TOKEN = $token
        return $token
    } else {
        Write-Host "Failed to get auth token" -ForegroundColor Red
        return $null
    }
}

function Invoke-ModelTraining {
    Write-Host "Training BigQuery ML model..." -ForegroundColor Green
    Get-Content train_model.sql | bq query --use_legacy_sql=false
}

function Invoke-ModelEvaluation {
    Write-Host "Evaluating model..." -ForegroundColor Green
    Get-Content evaluate_model.sql | bq query --use_legacy_sql=false
}

function Invoke-ModelExplanation {
    Write-Host "Getting feature importance..." -ForegroundColor Green
    Get-Content explain_model.sql | bq query --use_legacy_sql=false
}

function Build-DockerImage {
    Write-Host "Building Docker image..." -ForegroundColor Green
    docker build -t "gcr.io/$PROJECT_ID/$IMAGE_NAME:latest" .
}

function Push-DockerImage {
    Write-Host "Pushing image to GCR..." -ForegroundColor Green
    docker push "gcr.io/$PROJECT_ID/$IMAGE_NAME:latest"
}

function Deploy-CloudRun {
    Write-Host "Deploying to Cloud Run..." -ForegroundColor Green
    $imagePath = "gcr.io/$PROJECT_ID/$IMAGE_NAME:latest"
    gcloud run deploy $SERVICE_NAME --image $imagePath --region $REGION --platform managed --min-instances 0 --memory 512Mi --timeout 30 --no-allow-unauthenticated
}

function Build-And-Deploy {
    Build-DockerImage
    if ($LASTEXITCODE -eq 0) {
        Push-DockerImage
        if ($LASTEXITCODE -eq 0) {
            Deploy-CloudRun
        }
    }
}

function Test-API {
    param([int]$Count = 5)
    
    $url = Get-ServiceUrl
    $token = Get-AuthToken
    
    if (-not $url -or -not $token) {
        Write-Host "Cannot test: service URL or auth token unavailable" -ForegroundColor Red
        return
    }
    
    Write-Host "Running $Count smoke tests..." -ForegroundColor Green
    Write-Host "   Service URL: $url" -ForegroundColor Cyan
    Write-Host ""
    
    1..$Count | ForEach-Object {
        Write-Host "--- Request $_ ---" -ForegroundColor Yellow
        $response = curl -X POST "$url/predict" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "@test_request.json"
        Write-Output $response
        Write-Host ""
    }
}

function Show-Status {
    Write-Host "`nCurrent Status:" -ForegroundColor Green
    Write-Host "   Project:       $PROJECT_ID" -ForegroundColor Cyan
    Write-Host "   Service Name:  $SERVICE_NAME" -ForegroundColor Cyan
    Write-Host "   Region:        $REGION" -ForegroundColor Cyan
    
    $url = Get-ServiceUrl
    if ($url) {
        Write-Host "   Service URL:   $url" -ForegroundColor Cyan
    } else {
        Write-Host "   Service URL:   Not deployed" -ForegroundColor Yellow
    }
    
    $model_exists = bq show "$DATASET.$MODEL_NAME" 2>$null
    if ($model_exists) {
        Write-Host "   Model:         $DATASET.$MODEL_NAME (exists)" -ForegroundColor Cyan
    } else {
        Write-Host "   Model:         Not trained yet" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Show-Help {
    Write-Host "`nAvailable Commands:" -ForegroundColor Green
    Write-Host ""
    Write-Host "Model Training & Evaluation:" -ForegroundColor Yellow
    Write-Host "  Invoke-ModelTraining      - Train the BigQuery ML model"
    Write-Host "  Invoke-ModelEvaluation    - Evaluate model performance"
    Write-Host "  Invoke-ModelExplanation   - Get feature importance"
    Write-Host ""
    Write-Host "Docker & Deployment:" -ForegroundColor Yellow
    Write-Host "  Build-DockerImage         - Build Docker image locally"
    Write-Host "  Push-DockerImage          - Push image to GCR"
    Write-Host "  Deploy-CloudRun           - Deploy to Cloud Run"
    Write-Host "  Build-And-Deploy          - Do all three at once"
    Write-Host ""
    Write-Host "Testing:" -ForegroundColor Yellow
    Write-Host "  Test-API                  - Run 5 smoke tests"
    Write-Host "  Test-API -Count 10        - Run 10 smoke tests"
    Write-Host ""
    Write-Host "Utilities:" -ForegroundColor Yellow
    Write-Host "  Get-ServiceUrl            - Get Cloud Run service URL"
    Write-Host "  Get-AuthToken             - Get fresh auth token"
    Write-Host "  Show-Status               - Show current deployment status"
    Write-Host "  Show-Help                 - Show this help message"
    Write-Host ""
    Write-Host "Variables:" -ForegroundColor Yellow
    Write-Host "  `$PROJECT_ID, `$REGION, `$SERVICE_NAME, `$IMAGE_NAME"
    Write-Host "  `$DATASET, `$MODEL_NAME, `$SERVICE_URL, `$TOKEN"
    Write-Host ""
}

Write-Host "Type 'Show-Help' to see available commands" -ForegroundColor Cyan
Write-Host ""
