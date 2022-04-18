-- CREATE MONETARY VALUE SEGMENTATION --
WITH 
-- Aggregate data on a monthly level
aggregate AS (
    SELECT 
        customer_guid
        , DATE_TRUNC(transaction_date, MONTH)                                                           AS transaction_month
        , SUM(COALESCE(transaction_value_debit_cards,0) + COALESCE(transaction_value_credit_cards,0))   AS total_monthly_value
        , SUM(transaction_count_debit_cards + transaction_count_credit_cards)                           AS total_monthly_count
    FROM `sandbox-edeveer.dojo.customer_transactions`
    GROUP BY 1, 2
)
-- Create average monthly value percentiles 
, percentiles AS (
    SELECT 
        customer_guid
        , avg_monthly_value
        , PERCENTILE_CONT(avg_monthly_value, 0.25) OVER () AS percentile_25
        , PERCENTILE_CONT(avg_monthly_value, 0.75) OVER () AS percentile_75
    FROM (
        SELECT 
            customer_guid
            , AVG(total_monthly_value) AS avg_monthly_value
        FROM aggregate
        GROUP BY 1
        )
)
-- Assign monetary segmentation to customers based on value percentiles
, monetary_segmentation AS (
    SELECT 
        customer_guid
        , CASE
            WHEN avg_monthly_value < percentile_25
            THEN 3
            WHEN avg_monthly_value BETWEEN percentile_25 AND percentile_75
            THEN 2
            WHEN avg_monthly_value > percentile_75
            THEN 1
        END AS monetary_segment
    FROM percentiles
)

SELECT * 
FROM monetary_segmentation
ORDER BY 1
