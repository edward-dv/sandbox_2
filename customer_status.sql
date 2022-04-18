-- ASSIGN CUSTOMER STATUS AND COUNT INACTIVE WEEKS --
WITH 
-- Prep dates
dates_prep AS (
    SELECT 
        MIN(transaction_date) AS min_date
        , MAX(transaction_date) AS max_date
    FROM`sandbox-edeveer.dojo.customer_transactions`
)
-- Generate date array
, dates AS (
    SELECT 
        customer_guid
        , week
    FROM `sandbox-edeveer.dojo.customer_transactions`
    LEFT JOIN UNNEST((SELECT 
                    GENERATE_DATE_ARRAY(min_date, max_date, INTERVAL 1 WEEK) 
                    FROM dates_prep)
                ) AS week
)
-- Aggregate data on a monthly level and add date array
, aggregate AS (
    SELECT 
        ct.customer_guid
        , DATE_TRUNC(ct.transaction_date, ISOWEEK)                                                      AS week
        , SUM(COALESCE(transaction_value_debit_cards,0) + COALESCE(transaction_value_credit_cards,0))   AS total_weekly_value
        , SUM(transaction_count_debit_cards + transaction_count_credit_cards)                           AS total_weekly_count
    FROM `sandbox-edeveer.dojo.customer_transactions` AS ct
    GROUP BY 1, 2

    UNION DISTINCT

    SELECT 
        customer_guid
        , week
        , null AS total_weekly_value
        , null AS total_weekly_count
    FROM dates
)
-- Create customer statu
, status AS (
    SELECT 
        customer_guid
        , week
        , MAX(total_weekly_value) AS total_weekly_value
        , MAX(total_weekly_count) AS total_weekly_count
        , CASE 
            WHEN MAX(total_weekly_count) > 0
            THEN 'Active'
            WHEN MAX(total_weekly_count) = 0
            THEN 'Inactive'
            WHEN MAX(total_weekly_count) IS NULL
            THEN 'Churned'
        END AS customer_status
    FROM aggregate 
    GROUP BY 1,2
    ORDER BY 1,2
)
-- Prep for week count
, prep AS ( 
    SELECT 
        status.*
        , IF((LAG(customer_status) OVER (PARTITION BY customer_guid ORDER BY customer_guid, week)) != customer_status, 1, 0) AS tool
    FROM status
)
-- Consolidate and add inactive weeks count
SELECT 
customer_guid
, week
, total_weekly_value
, total_weekly_count
, customer_status
, SUM(CASE WHEN customer_status = 'Inactive' THEN 1 ELSE 0 END) OVER (PARTITION BY customer_guid, customer_status, tool_2 ORDER BY customer_guid, week) AS inactive_weeks_count 
FROM (
    SELECT 
        prep.*
        , SUM(tool) OVER (PARTITION BY customer_guid ORDER BY customer_guid, week) AS tool_2
    FROM prep
    )
ORDER BY 1,2
