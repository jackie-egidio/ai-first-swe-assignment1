-- BigQuery ML Credit Card Default Risk Model Training
-- Stevens ID: your-stevens-id

CREATE OR REPLACE MODEL `your_stevens_id_ml.default_risk_v1`
OPTIONS(
  model_type='BOOSTED_TREE_CLASSIFIER',
  input_label_cols=['default_payment_next_month'],
  auto_class_weights=TRUE,
  max_iterations=50,
  enable_global_explain=TRUE
) AS
SELECT
  -- Demographic features
  limit_balance,
  sex,
  education_level,
  marital_status,
  age,
  
  -- Payment status features (PAY_0 to PAY_6)
  pay_0,
  pay_2,
  pay_3,
  pay_4,
  pay_5,
  pay_6,
  
  -- Bill amount features (BILL_AMT_1 to BILL_AMT_6)
  bill_amt_1,
  bill_amt_2,
  bill_amt_3,
  bill_amt_4,
  bill_amt_5,
  bill_amt_6,
  
  -- Payment amount features (PAY_AMT_1 to PAY_AMT_6)
  pay_amt_1,
  pay_amt_2,
  pay_amt_3,
  pay_amt_4,
  pay_amt_5,
  pay_amt_6,
  
  -- Target variable
  default_payment_next_month
FROM
  `bigquery-public-data.ml_datasets.credit_card_default`
WHERE
  -- Split data: 80% for training, 20% for evaluation
  MOD(ABS(FARM_FINGERPRINT(CAST(id AS STRING))), 10) < 8;
