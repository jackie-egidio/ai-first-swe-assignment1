"""
FastAPI Credit Card Default Risk Inference API
Uses BigQuery ML.PREDICT to get predictions from the trained model
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from google.cloud import bigquery
import os
from typing import Optional

app = FastAPI(
    title="Credit Card Default Risk API",
    description="Predict credit card default risk using BigQuery ML",
    version="1.0.0"
)

# Initialize BigQuery client
client = bigquery.Client()

# Model configuration
PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT")
MODEL_NAME = "your_stevens_id_ml.default_risk_v1"


class PredictionRequest(BaseModel):
    """Input features for credit card default prediction"""
    limit_balance: float = Field(..., description="Credit limit in NT dollars")
    sex: str = Field(..., description="Gender (1=male, 2=female)")
    education_level: str = Field(..., description="Education level (1-6)")
    marital_status: str = Field(..., description="Marital status (1=married, 2=single, 3=others)")
    age: float = Field(..., description="Age in years")
    
    # Payment status for past 6 months
    pay_0: float = Field(..., description="Payment status in September")
    pay_2: float = Field(..., description="Payment status in August")
    pay_3: float = Field(..., description="Payment status in July")
    pay_4: float = Field(..., description="Payment status in June")
    pay_5: str = Field(..., description="Payment status in May")
    pay_6: str = Field(..., description="Payment status in April")
    
    # Bill amounts for past 6 months
    bill_amt_1: float = Field(..., description="Bill amount in September (NT$)")
    bill_amt_2: float = Field(..., description="Bill amount in August (NT$)")
    bill_amt_3: float = Field(..., description="Bill amount in July (NT$)")
    bill_amt_4: float = Field(..., description="Bill amount in June (NT$)")
    bill_amt_5: float = Field(..., description="Bill amount in May (NT$)")
    bill_amt_6: float = Field(..., description="Bill amount in April (NT$)")
    
    # Payment amounts for past 6 months
    pay_amt_1: float = Field(..., description="Payment amount in September (NT$)")
    pay_amt_2: float = Field(..., description="Payment amount in August (NT$)")
    pay_amt_3: float = Field(..., description="Payment amount in July (NT$)")
    pay_amt_4: float = Field(..., description="Payment amount in June (NT$)")
    pay_amt_5: float = Field(..., description="Payment amount in May (NT$)")
    pay_amt_6: float = Field(..., description="Payment amount in April (NT$)")


class PredictionResponse(BaseModel):
    """Prediction output"""
    predicted_label: str
    prediction_probability: Optional[float] = None


@app.get("/")
def read_root():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "Credit Card Default Risk API",
        "model": MODEL_NAME
    }


@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {"status": "ok"}


@app.post("/predict", response_model=PredictionResponse)
def predict(request: PredictionRequest):
    """
    Predict credit card default risk using BigQuery ML model
    
    Returns predicted label and probability
    """
    try:
        # Build ML.PREDICT query
        query = f"""
        SELECT
          predicted_default_payment_next_month,
          predicted_default_payment_next_month_probs
        FROM
          ML.PREDICT(MODEL `{PROJECT_ID}.{MODEL_NAME}`,
            (
            SELECT
              {request.limit_balance} AS limit_balance,
              '{request.sex}' AS sex,
              '{request.education_level}' AS education_level,
              '{request.marital_status}' AS marital_status,
              {request.age} AS age,
              {request.pay_0} AS pay_0,
              {request.pay_2} AS pay_2,
              {request.pay_3} AS pay_3,
              {request.pay_4} AS pay_4,
              '{request.pay_5}' AS pay_5,
              '{request.pay_6}' AS pay_6,
              {request.bill_amt_1} AS bill_amt_1,
              {request.bill_amt_2} AS bill_amt_2,
              {request.bill_amt_3} AS bill_amt_3,
              {request.bill_amt_4} AS bill_amt_4,
              {request.bill_amt_5} AS bill_amt_5,
              {request.bill_amt_6} AS bill_amt_6,
              {request.pay_amt_1} AS pay_amt_1,
              {request.pay_amt_2} AS pay_amt_2,
              {request.pay_amt_3} AS pay_amt_3,
              {request.pay_amt_4} AS pay_amt_4,
              {request.pay_amt_5} AS pay_amt_5,
              {request.pay_amt_6} AS pay_amt_6
            )
          )
        """
        
        # Execute query
        query_job = client.query(query)
        results = query_job.result()
        
        # Parse results
        for row in results:
            predicted_label = row.predicted_default_payment_next_month
            probabilities = row.predicted_default_payment_next_month_probs
            
            # Extract probability for the predicted class
            prob = None
            if probabilities:
                for p in probabilities:
                    if p['label'] == predicted_label:
                        prob = p['prob']
                        break
            
            return PredictionResponse(
                predicted_label=predicted_label,
                prediction_probability=prob
            )
        
        # If no results, raise error
        raise HTTPException(status_code=500, detail="No prediction returned from model")
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
