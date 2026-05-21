# System Architecture: Credit Default Risk ML Inference Service

## Overview

This document describes the architecture of a machine learning inference service for credit default risk prediction, deployed on Google Cloud Platform. The system leverages BigQuery ML for model training and inference, Cloud Run for scalable API hosting, and Artifact Registry for container management.

---

## Architecture Components

### 1. CI/CD Pipeline

**Architecture Flow:**
```
Developer Workstation → Docker Build → Artifact Registry → Cloud Run Deployment
```

**Components:**
- **Developer Workstation**: Local development environment with Docker CLI
- **Artifact Registry**: Container registry at `us-east4-docker.pkg.dev/{project-id}/{repo-name}`
- **Cloud Run Service**: Deployed service `{service-name}` in us-east4 region

**Key Commands:**
- Build: `docker build -t us-east4-docker.pkg.dev/{project-id}/{repo-name}/{image-name}:v2`
- Push: `docker push` (requires `roles/artifactregistry.writer`)
- Deploy: `gcloud run deploy --image` (requires `roles/run.admin`)

**Justification:**
- **Artifact Registry over GCR**: Artifact Registry is the next-generation container registry offering improved security, multi-region support, and better integration with GCP services
- **Image-based deployment**: Using pre-built container images rather than source deployment provides consistent, reproducible deployments and faster rollback capabilities
- **Regional deployment (us-east4)**: Keeps all components (model, registry, service) in the same region to minimize latency and data transfer costs

---

### 2. Machine Learning Training Pipeline

**Architecture Flow:**
```
BigQuery Public Dataset → BQML Training → Model Storage → Evaluation
```

**Components:**
- **Source Dataset**: `bigquery-public-data.ml_datasets.credit_card_default` (30,000 records, 25 features)
- **Training Algorithm**: Boosted Tree Classifier
- **Model Storage**: `{dataset_id}.default_risk_v1` in us-east4
- **Evaluation**: ML.EVALUATE and ML.GLOBAL_EXPLAIN functions

**Model Specifications:**
- 80/20 train/test split
- Global explainability enabled (`enable_global_explain=TRUE`)
- Features: limit_balance, age, education_level, marital_status, payment history (pay_0-6), billing amounts (bill_amt_1-6), payment amounts (pay_amt_1-6)
- Target: default_payment_next_month

**Justification:**
- **BigQuery ML**: Eliminates the need to export data and train models separately, reducing data movement and infrastructure complexity
- **Boosted Tree Classifier**: Provides excellent performance for tabular credit risk data with interpretable feature importance
- **Global explainability**: Enables model transparency and regulatory compliance for financial services applications
- **Public dataset usage**: Leverages Google's managed dataset infrastructure for reliable, production-grade training data

---

### 3. Inference Service Architecture

**Architecture Flow:**
```
Authenticated Client → Cloud Run (FastAPI) → BigQuery ML.PREDICT → Model → Response
```

**Components:**
- **API Framework**: FastAPI with Uvicorn server on port 8080
- **Container Base**: Python 3.12-slim for minimal attack surface
- **Input Validation**: Pydantic models enforcing 25-feature schema
- **Endpoint**: POST `https://{service-name}-*.us-east4.run.app/predict`
- **Authentication**: Bearer token authentication

**Request/Response Example:**
```json
Request:
{
  "limit_balance": 20000,
  "age": 24,
  "education_level": 2,
  ...
}

Response:
{
  "predicted_label": 0,
  "prediction_probability": 0.85
}
```

**Performance:**
- Latency: 1-3 seconds (dominated by BigQuery ML.PREDICT execution)
- Scalability: Cloud Run auto-scaling 0 to N instances

**Justification:**
- **Cloud Run**: Provides serverless auto-scaling, pay-per-use pricing, and automatic HTTPS without managing infrastructure
- **FastAPI**: Modern Python framework with automatic OpenAPI documentation, async support, and built-in data validation
- **ML.PREDICT in BigQuery**: Keeps model and data in same platform, eliminating export overhead and ensuring consistent predictions
- **Pydantic validation**: Prevents invalid inputs from reaching the model, reducing errors and improving security
- **Python 3.12-slim**: Balances compatibility with minimal image size for faster cold starts

---

### 4. Identity and Access Management (IAM)

**Security Boundaries:**

**Developer Permissions:**
- Service Account: `{stevens-id}@company.com`
- Role: `roles/artifactregistry.writer` - Push container images to Artifact Registry
- Role: `roles/run.admin` - Deploy services to Cloud Run

**Cloud Run Service Account:**
- Role: `roles/bigquery.user` - Execute queries against BigQuery
- Role: `roles/bigquery.dataViewer` - Read model definitions and metadata

**Client Authentication:**
- Role: `roles/run.invoker` - Invoke Cloud Run service endpoints
- Authentication: Bearer token via `gcloud auth print-identity-token`

**BigQuery Service Account:**
- Role: `roles/bigquery.dataOwner` - Manage datasets and models

**Justification:**
- **Principle of least privilege**: Each component receives only the minimum permissions required for its function
- **Service-to-service authentication**: Uses GCP-native IAM instead of API keys, eliminating credential management risks
- **Authenticated endpoints**: Prevents unauthorized access to prediction service
- **No hardcoded credentials**: All authentication handled via IAM roles and service accounts

---

### 5. Secret Management (Production Pattern)

**Architecture Flow:**
```
Secret Manager → Vault Storage → Cloud Run (Environment Variables)
```

**Secret Types:**
- API keys for external services
- Database credentials
- Service account JSON keys

**Integration:**
- Secrets mounted as environment variables at runtime
- Cloud Run service account requires `roles/secretmanager.secretAccessor`

**Justification:**
- **Centralized secret management**: Single source of truth for sensitive configuration
- **Runtime injection**: Secrets never stored in container images or source code
- **Audit trail**: Secret Manager logs all access attempts for compliance
- **Rotation support**: Enables credential rotation without redeploying services
- **Note**: This pattern is documented for production readiness but not actively used in the current implementation, which relies on environment variables

---

## Architecture Decisions Summary

### Technology Selection

| Decision | Choice | Justification |
|----------|--------|---------------|
| **ML Platform** | BigQuery ML | Integrated training and inference, no data export needed, managed infrastructure |
| **API Framework** | FastAPI | Modern async support, automatic validation, OpenAPI docs, excellent Python ecosystem |
| **Hosting** | Cloud Run | Serverless scaling, pay-per-use, automatic HTTPS, zero infrastructure management |
| **Container Registry** | Artifact Registry | Next-gen registry, better security, multi-region replication |
| **Region** | us-east4 | Consistent regional deployment reduces latency and data transfer costs |
| **Authentication** | IAM Tokens | Native GCP integration, no credential management, audit logging |

### Architectural Patterns

1. **Separation of Concerns**: Training pipeline isolated from inference service, enabling independent updates
2. **Stateless API**: Cloud Run instances maintain no state, enabling horizontal scaling
3. **Defense in Depth**: Multiple security layers (IAM, input validation, HTTPS, secret management)
4. **Infrastructure as Code**: Deployment commands documented for reproducible infrastructure
5. **Development-Production Parity**: Docker containerization ensures consistency across environments

---

## Data Flow Architecture

### Training Flow
1. Access public credit card default dataset in BigQuery
2. Train boosted tree classifier using BQML with 80/20 split
3. Store model in BigQuery dataset `{dataset_id}`
4. Evaluate model performance and generate explainability metrics

### Inference Flow
1. Client obtains authentication token from GCP
2. Client sends POST request with 25 features to Cloud Run endpoint
3. FastAPI validates input against Pydantic schema
4. Service executes ML.PREDICT query against BigQuery model
5. BigQuery returns prediction label and probability
6. Service formats response and returns to client

### Deployment Flow
1. Developer builds Docker image locally with Python 3.12 runtime
2. Image pushed to Artifact Registry in us-east4
3. Cloud Run deployment references image by digest
4. Service configured with environment variables and IAM roles
5. HTTPS endpoint automatically provisioned

---

## Operational Characteristics

**Scalability:**
- Cloud Run: Automatic scaling from 0 to N instances based on request volume
- BigQuery ML: Handles concurrent predictions through managed infrastructure

**Reliability:**
- Health checks: Cloud Run automatic health monitoring
- Retries: Built-in request retry logic for transient failures
- Regional isolation: All components in us-east4 reduce cross-region dependencies

**Security:**
- Transport: HTTPS enforced for all client communications
- Authentication: Bearer token validation on every request
- Authorization: IAM roles enforce least-privilege access
- Input validation: Pydantic prevents malformed requests

**Observability:**
- Logging: Cloud Run automatic request/response logging
- Monitoring: GCP console provides latency, error rate, and throughput metrics
- Tracing: Request IDs enable end-to-end transaction tracking

---

## Architecture Diagram Reference

A visual representation of this architecture should include:

**CI/CD Pipeline (Top Section):**
- Developer workstation → Docker build → Artifact Registry → Cloud Run deployment
- IAM annotations showing required roles at each step

**Training & Inference (Middle Section):**
- Left: BigQuery dataset → BQML training → Model storage → Evaluation
- Right: Client → Cloud Run → ML.PREDICT → Response
- Both flows showing data transformations and IAM boundaries

**Secret Management (Bottom Section):**
- Secret Manager vault → Secrets → Cloud Run service
- Production pattern for credential management

**Visual Elements:**
- Green arrows: CI/CD pipeline flow
- Blue arrows: Data/inference flow
- Orange dashed lines: IAM/security boundaries
- Red box: Security zone (Secret Manager)
- GCP service icons for BigQuery, Cloud Run, Artifact Registry, Secret Manager

---

*Architecture version: 2.0*  
*Last updated: May 2026*  
*Region: us-east4*
