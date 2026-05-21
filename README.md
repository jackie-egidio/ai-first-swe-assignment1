# Assignment 1: Cloud-Native AI Inference API

## Project Overview
Build and deploy a cloud-native AI inference API for credit card default risk prediction using BigQuery ML and Cloud Run.

**Stevens ID:** *(your-stevens-id)*  
**Dataset:** `bigquery-public-data.ml_datasets.credit_card_default`  
**Model:** `your_stevens_id_ml.default_risk_v1`  
**Cloud Run Service:** `your-stevens-id-inference-api`  
**Region:** `us-east4` *(or your preferred region)*

---

## Quick Start with Helper Script

To avoid re-typing credentials and commands, use the PowerShell helper script:

```powershell
# Load the environment (do this once per terminal session)
. .\setup.ps1

# Now you can use simple commands:
Build-And-Deploy          # Build, push, and deploy
Test-API                  # Run smoke tests
Show-Status               # Check deployment status
Show-Help                 # See all available commands
```

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for complete documentation of all helper commands.

---

## Project Structure

```
assignment1/
├── README.md                     # This file - complete guide
├── SETUP_GUIDE.md                # PowerShell helper script guide
├── setup.ps1                     # PowerShell environment setup
│
├── SQL files (BigQuery ML)
│   ├── train_model.sql          # Model training query
│   ├── evaluate_model.sql       # Model evaluation query
│   └── explain_model.sql        # Feature importance query
│
├── API files (FastAPI)
│   ├── main.py                  # FastAPI application
│   ├── requirements.txt         # Python dependencies
│   ├── .python-version          # Python version (3.12)
│   ├── Dockerfile               # Docker container configuration
│   └── test_request.json        # Sample API request
│
├── EDA Analysis
│   └── results_eda_notebook.ipynb  # Phase 4 exploratory data analysis
│
├── Deployment Guides
│   └── DOCKER_DEPLOYMENT.md     # Local Docker deployment
│
├── docs/
│   └── ARCHITECTURE_DIAGRAM_GUIDE.md  # Architecture decisions document
│
└── .gitignore                   # Git ignore configuration
```

---

## Phase 2: BigQuery ML Model

### Overview
Train a boosted tree classifier using BigQuery ML to predict credit card default risk.

**Key Features:**
- 25 input features (demographics, payment history, bill amounts, payment amounts)
- Boosted tree classifier with explainability enabled
- 80/20 train/test split using hash-based sampling

### Step 1: Train the Model

Run the training query:

```powershell
Get-Content train_model.sql | bq query --use_legacy_sql=false
```

**Expected time:** 2-5 minutes

The model includes:
- Correct column names: `limit_balance`, `education_level`, `marital_status`, `bill_amt_1`, etc.
- `enable_global_explain=TRUE` for feature importance analysis
- Auto class weights to handle imbalanced data

### Step 2: Evaluate the Model

Get performance metrics:

```powershell
Get-Content evaluate_model.sql | bq query --use_legacy_sql=false
```

**📸 Required Screenshot:** Capture results showing `roc_auc`, `accuracy`, `precision`, and `recall`

### Step 3: Explain Feature Importance

Get top features contributing to predictions:

```powershell
Get-Content explain_model.sql | bq query --use_legacy_sql=false
```

**📸 Required Screenshot:** Capture top 5 features with attribution scores

### Phase 2 Troubleshooting

**Error: "The '<' operator is reserved for future use"**
- PowerShell doesn't support `<` for input redirection
- Use `Get-Content filename.sql | bq query --use_legacy_sql=false`

**Error: "Unrecognized name: limit_bal"**
- Column names have been corrected in all SQL files
- Correct names: `limit_balance`, `education_level`, `marital_status`, `bill_amt_1`, `pay_amt_1`

**Error: "Invalid table-valued function ML.GLOBAL_EXPLAIN"**
- Model must be trained with `enable_global_explain=TRUE` (already included)
- If you trained before this was added, retrain the model

---

## Phase 3: FastAPI Cloud Run API

### Overview
Deploy a FastAPI inference service that calls your BigQuery ML model via `ML.PREDICT`.

**Endpoints:**
- `GET /` - Service info and health check
- `GET /health` - Health status
- `POST /predict` - Get default risk prediction

---

### Deployment Method A: Workbench Docker Build (Recommended)

This method uses Vertex AI Workbench to build and deploy your Docker image, which is recommended for corporate/managed GCP environments.

#### Step 1: Create Workbench Instance

1. Open Google Cloud Console: https://console.cloud.google.com
2. Navigate to: **Vertex AI → Workbench**
3. Click **"Create New"** → **"Workbench Instance"**
4. Configure:
   - **Name:** `docker-build` (or `your-stevens-id-docker-build`)
   - **Region:** `us-east4`
   - **Zone:** `us-east4-a`
   - Use default machine type (e2-standard-4 is fine)
5. Click **"Create"**
6. Wait 2-3 minutes for instance to be ready
7. Click **"Open JupyterLab"** button

#### Step 2: Set Up Workbench Environment

Open Terminal in JupyterLab (File → New → Terminal):

```bash
# Set active project
gcloud config set project YOUR_PROJECT_ID

# Verify authentication
gcloud auth list
```

#### Step 3: Create Artifact Registry Repository

Create a repository for your Docker images (only needs to be done once):

```bash
gcloud artifacts repositories create your-inference-repo \
  --repository-format=docker \
  --location=us-east4 \
  --project=YOUR_PROJECT_ID
```

Configure Docker authentication:

```bash
gcloud auth configure-docker us-east4-docker.pkg.dev
```

#### Step 4: Upload Application Files

Choose one of these methods to get your code into Workbench:

**Option A: Upload via JupyterLab UI (Easiest)**
1. Create a new folder: `assignment1`
2. Drag and drop files: `main.py`, `requirements.txt`, `Dockerfile`, `.python-version`, `test_request.json`

**Option B: Clone from GitHub**
```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO/assignment1
```

**Option C: Copy from Local Machine**
```powershell
# From your local PowerShell
gcloud workbench instances list --location=us-east4
gcloud compute scp --recurse assignment1 docker-build:~/ --zone=us-east4-a
```

#### Step 5: Build Docker Image

Navigate to your application folder:

```bash
cd assignment1
ls -la
```

Build the Docker image:

```bash
docker build -t us-east4-docker.pkg.dev/YOUR_PROJECT_ID/your-inference-repo/your-inference-api:v1 .
```

**Expected time:** 2-3 minutes

#### Step 6: Push to Artifact Registry

```bash
docker push us-east4-docker.pkg.dev/YOUR_PROJECT_ID/your-inference-repo/your-inference-api:v1
```

**Expected time:** 1-2 minutes

#### Step 7: Deploy to Cloud Run

```bash
gcloud run deploy your-inference-api \
  --image us-east4-docker.pkg.dev/YOUR_PROJECT_ID/your-inference-repo/your-inference-api:v1 \
  --region us-east4 \
  --platform managed \
  --min-instances 0 \
  --memory 512Mi \
  --timeout 30 \
  --no-allow-unauthenticated
```

**Expected time:** 1-2 minutes

#### Step 8: Get Service URL

```bash
gcloud run services describe your-inference-api --region us-east4 --format="value(status.url)"
```

Save this URL for testing!

#### Step 9: Run Smoke Tests

Get authentication token:

```bash
TOKEN=$(gcloud auth print-identity-token)
```

Set your service URL:

```bash
SERVICE_URL="https://your-inference-api-XXXXXXXXX.us-east4.run.app"
```

Run 5 test requests:

```bash
for i in {1..5}; do
  echo "========================================="
  echo "Request $i"
  echo "========================================="
  
  response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$SERVICE_URL/predict" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d @test_request.json)
  
  http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
  body=$(echo "$response" | sed '/HTTP_STATUS:/d')
  
  echo "HTTP Status: $http_status"
  echo "Response Body:"
  echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
  echo ""
done
```

**📸 Required Screenshot:** Capture output showing 5 requests with HTTP 200 and `predicted_label`

---

### Deployment Method B: Local Docker Build

If you have Docker Desktop installed locally:

```powershell
# Build image
docker build -t us-east4-docker.pkg.dev/YOUR_PROJECT_ID/your-inference-repo/your-inference-api:v1 .

# Authenticate (one-time)
gcloud auth configure-docker us-east4-docker.pkg.dev

# Push to Artifact Registry
docker push us-east4-docker.pkg.dev/YOUR_PROJECT_ID/your-inference-repo/your-inference-api:v1

# Deploy to Cloud Run
gcloud run deploy your-inference-api `
  --image us-east4-docker.pkg.dev/YOUR_PROJECT_ID/your-inference-repo/your-inference-api:v1 `
  --region us-east4 `
  --platform managed `
  --min-instances 0 `
  --memory 512Mi `
  --timeout 30 `
  --no-allow-unauthenticated
```

### Testing from PowerShell (Local Machine)

```powershell
# Get authentication token
$TOKEN = gcloud auth print-identity-token

# Set service URL
$SERVICE_URL = "YOUR_SERVICE_URL"

# Run 5 test requests
1..5 | ForEach-Object {
  Write-Host "`n--- Request $_ ---"
  curl -X POST "$SERVICE_URL/predict" `
    -H "Authorization: Bearer $TOKEN" `
    -H "Content-Type: application/json" `
    -d "@test_request.json"
}
```

---

### Optional: Test Locally Before Deploying

```powershell
# Create virtual environment
python -m venv venv
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Set GCP project
$env:GOOGLE_CLOUD_PROJECT = "YOUR_PROJECT_ID"

# Run locally
python main.py
```

Test locally:

```powershell
curl -X POST http://localhost:8080/predict `
  -H "Content-Type: application/json" `
  -d "@test_request.json"
```

---

### Phase 3 Troubleshooting

**Error: "Repository not found"**
- Make sure you created the Artifact Registry repository (Step 3)
- Verify repository name matches in all commands

**Error: "Permission denied" when pushing**
- Run: `gcloud auth configure-docker us-east4-docker.pkg.dev`
- Verify: `gcloud auth list` shows your account

**Error: "Cannot connect to Docker daemon"**
- Docker should be pre-installed in Workbench
- Try: `sudo systemctl start docker`

**Build fails with "no space left"**
- Delete old images: `docker system prune -a`

**Cloud Run deployment fails**
- Verify the image was pushed: Check Artifact Registry in console
- Check you have Cloud Run deployment permissions

**Error: "Model not found" in predictions**
- Verify model exists: `bq ls your_stevens_id_ml`
- Check model name matches in code

**Slow response times (2-3 seconds)**
- This is expected! `ML.PREDICT` runs as a BigQuery query job
- Each prediction is a full query execution

**403 Forbidden when testing**
- Service uses authentication (`--no-allow-unauthenticated`)
- Generate token: `gcloud auth print-identity-token`

**401 Unauthorized**
- Token expired (tokens expire after 1 hour)
- Regenerate: `$TOKEN = gcloud auth print-identity-token`

---

## Important Notes

### Column Names
The dataset uses these column names (use exactly as shown):
- `limit_balance` (not `limit_bal`)
- `education_level` (not `education`)
- `marital_status` (not `marriage`)
- `bill_amt_1` through `bill_amt_6` (with underscores)
- `pay_amt_1` through `pay_amt_6` (with underscores)

### Authentication
Cloud Run service is deployed with authentication required. Always include the Bearer token when making requests.

### Cost Management
- BigQuery: Pay per query (typically < $1 for this assignment)
- Cloud Run: Pay per request + compute time
- Set `--min-instances 0` to avoid idle charges
- Delete Workbench instance after completing assignment

---

## Deliverables Checklist

### Phase 2: BigQuery ML
- [ ] `train_model.sql` - Model training query
- [ ] Screenshot of ML.EVALUATE results
- [ ] Screenshot of ML.GLOBAL_EXPLAIN output (top 5 features)

### Phase 3: Cloud Run API
- [ ] `main.py` - FastAPI application
- [ ] `requirements.txt` - Python dependencies
- [ ] `.python-version` - Python version file
- [ ] `Dockerfile` - Docker container configuration
- [ ] Screenshot of Cloud Run service page
- [ ] Screenshot of smoke test output (5 requests, HTTP 200, with `predicted_label`)

### Phase 4: EDA Notebook
- [ ] `results_eda_notebook.ipynb` - Exploratory data analysis
- [ ] Correlation heatmap
- [ ] Distribution plots
- [ ] Missing value analysis
- [ ] 5+ observations

### Phase 5: Architecture Diagram
- [ ] `docs/ARCHITECTURE_DIAGRAM_GUIDE.md` - Architecture decisions and justifications

---

## Quick Reference Commands

```powershell
# Phase 2: Train and evaluate model
Get-Content train_model.sql | bq query --use_legacy_sql=false
Get-Content evaluate_model.sql | bq query --use_legacy_sql=false
Get-Content explain_model.sql | bq query --use_legacy_sql=false

# Phase 3: Deploy API (from Workbench)
cd assignment1
docker build -t us-east4-docker.pkg.dev/YOUR_PROJECT_ID/your-repo/your-api:v1 .
docker push us-east4-docker.pkg.dev/YOUR_PROJECT_ID/your-repo/your-api:v1
gcloud run deploy your-api --image us-east4-docker.pkg.dev/YOUR_PROJECT_ID/your-repo/your-api:v1 --region us-east4 --no-allow-unauthenticated

# Get service URL
gcloud run services describe your-inference-api --region us-east4 --format="value(status.url)"

# Test API
$TOKEN = gcloud auth print-identity-token
curl -X POST "$SERVICE_URL/predict" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "@test_request.json"
```

---

## All-in-One Deployment Script (Bash - for Workbench)

```bash
# Set variables
PROJECT_ID="YOUR_PROJECT_ID"
REGION="us-east4"
REPO="your-inference-repo"
IMAGE_NAME="your-inference-api"
VERSION="v1"

# Navigate to code
cd assignment1

# Build
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/$REPO/$IMAGE_NAME:$VERSION .

# Push
docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPO/$IMAGE_NAME:$VERSION

# Deploy
gcloud run deploy $IMAGE_NAME \
  --image $REGION-docker.pkg.dev/$PROJECT_ID/$REPO/$IMAGE_NAME:$VERSION \
  --region $REGION \
  --platform managed \
  --min-instances 0 \
  --memory 512Mi \
  --timeout 30 \
  --no-allow-unauthenticated

# Get URL
gcloud run services describe $IMAGE_NAME --region $REGION --format="value(status.url)"
```
---

## Support

For issues or questions:
- Check troubleshooting sections above
- Review GCP documentation
- Check assignment discussion forum
- Contact course instructors
