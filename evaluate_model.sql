-- Evaluate the trained BigQuery ML model
-- Stevens ID: your-stevens-id

SELECT
  *
FROM
  ML.EVALUATE(MODEL `your_stevens_id_ml.default_risk_v1`,
    (
    SELECT
      limit_balance,
      sex,
      education_level,
      marital_status,
      age,
      pay_0,
      pay_2,
      pay_3,
      pay_4,
      pay_5,
      pay_6,
      bill_amt_1,
      bill_amt_2,
      bill_amt_3,
      bill_amt_4,
      bill_amt_5,
      bill_amt_6,
      pay_amt_1,
      pay_amt_2,
      pay_amt_3,
      pay_amt_4,
      pay_amt_5,
      pay_amt_6,
      default_payment_next_month
    FROM
      `bigquery-public-data.ml_datasets.credit_card_default`
    WHERE
      -- Use the 20% holdout set for evaluation
      MOD(ABS(FARM_FINGERPRINT(CAST(id AS STRING))), 10) >= 8
    )
  );

-- This query will return metrics including:
-- roc_auc, accuracy, precision, recall, f1_score, log_loss
