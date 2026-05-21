-- Get global feature importance from the trained model
-- Stevens ID: your-stevens-id

SELECT
  *
FROM
  ML.GLOBAL_EXPLAIN(MODEL `your_stevens_id_ml.default_risk_v1`)
ORDER BY
  attribution DESC
LIMIT 5;

-- This query returns the top 5 most important features
-- with their attribution scores (feature importance values)
