DATA CLEANING QUERIES:


1.	Check for inconsistent group–landing page combinations

SELECT *
FROM ab_data
WHERE ("group" = 'control' AND landing_page != 'old_page')
   OR ("group" = 'treatment' AND landing_page != 'new_page');


2.	Delete mismatched group–landing page combinations

DELETE FROM ab_data
WHERE ("group" = 'control' AND landing_page != 'old_page')
   OR ("group" = 'treatment' AND landing_page != 'new_page');


3.	Check for duplicate user_ids in ab_data
SELECT user_id, COUNT(*) 
FROM ab_data
GROUP BY user_id
HAVING COUNT(*) > 1;


4.	Remove duplicate user_ids in ab_data
WITH ranked_ab_data AS (
    SELECT ctid,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY timestamp) AS rn
    FROM ab_data
)
DELETE FROM ab_data
WHERE ctid IN (
    SELECT ctid
    FROM ranked_ab_data
    WHERE rn > 1
);


5.	Check for duplicate user_ids in countries
SELECT user_id, COUNT(*)
FROM countries
GROUP BY user_id
HAVING COUNT(*) > 1;


6.	Remove duplicate user_ids in countries

WITH ranked_countries AS (
    SELECT ctid,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY country) AS rn
    FROM countries
)
DELETE FROM countries
WHERE ctid IN (
    SELECT ctid FROM ranked_countries WHERE rn > 1
);


DATA PREPARATION ( JOINING TABLES)

1.	Create a view combining ab_data and countries

CREATE VIEW ab_cleaned AS
SELECT a.*, c.country
FROM ab_data a
LEFT JOIN countries c ON a.user_id = c.user_id;


DATA ANALYSIS QUERIES:


1.	Overall Conversion Rate by Group

SELECT "group",
       COUNT(*) AS total_users,
       SUM(converted) AS total_converted,
       ROUND((AVG(converted::float) * 100)::numeric, 2) AS conversion_rate
FROM ab_cleaned
GROUP BY "group";


2.	Absolute difference in conversion rates 

WITH conversion_rates AS (
    SELECT 
        "group",
        ROUND((AVG(converted::float) * 100)::numeric, 2) AS conversion_rate
    FROM ab_cleaned
    GROUP BY "group"
)

SELECT 
    ABS(
        MAX(CASE WHEN "group" = 'treatment' THEN conversion_rate END) -
        MAX(CASE WHEN "group" = 'control' THEN conversion_rate END)
    ) AS difference_in_conversion_rate
FROM conversion_rates;


3.	Statistical Significance (Z-test)

WITH stats AS (
    SELECT 
        17489::float AS x1,    -- conversions in control
        145274::float AS n1,   -- users in control
        17264::float AS x2,    -- conversions in treatment
        145311::float AS n2    -- users in treatment
),
rates AS (
    SELECT
        x1, n1, x2, n2,
        (x1 / n1) AS p1,
        (x2 / n2) AS p2,
        (x1 + x2) / (n1 + n2) AS p_pooled
    FROM stats
),
z_calc AS (
    SELECT
        p1, p2, p_pooled,
        SQRT(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2)) AS std_error,
        (p1 - p2) / 
        NULLIF(SQRT(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2)), 0) AS z_score
    FROM rates
)
SELECT 
    ROUND((p1 * 100)::numeric, 2) AS control_rate,
    ROUND((p2 * 100)::numeric, 2) AS treatment_rate,
    ROUND((z_score)::numeric, 4) AS z_statistic
FROM z_calc;


4.	Conversion Rate by Country:

SELECT country,
       COUNT(*) AS users,
       ROUND((AVG(converted::float) * 100)::numeric, 2) AS conversion_rate
FROM ab_cleaned
GROUP BY country
ORDER BY conversion_rate DESC;


5.	Conversion Rate by Country and Group:

SELECT country,
       "group",
       COUNT(*) AS total_users,
       SUM(converted) AS total_converted,
       ROUND((AVG(converted::float) * 100)::numeric, 2) AS conversion_rate
FROM ab_cleaned
GROUP BY country, "group"
ORDER BY country, "group";


6.	Overall Lift in conversion:

WITH conversion_rates AS (
    SELECT 
        "group",
        ROUND((AVG(converted::float) * 100)::numeric, 2) AS conversion_rate
    FROM ab_cleaned
    GROUP BY "group"
),
pivoted AS (
    SELECT 
        c.conversion_rate AS control_rate,
        t.conversion_rate AS treatment_rate,
        ROUND(((t.conversion_rate - c.conversion_rate) / c.conversion_rate) * 100, 2) AS lift_percent
    FROM conversion_rates c
    JOIN conversion_rates t ON c."group" = 'control' AND t."group" = 'treatment'
)
SELECT * FROM pivoted;


7.	Country wise Lift Calculation:

WITH conversion_rates AS (
    SELECT
        country,
        "group",
        ROUND((AVG(converted::float) * 100)::numeric, 2) AS conversion_rate
    FROM ab_cleaned
    GROUP BY country, "group"
),
pivoted AS (
    SELECT
        c.country,
        c.conversion_rate AS control_rate,
        t.conversion_rate AS treatment_rate,
        ROUND(((t.conversion_rate - c.conversion_rate) / c.conversion_rate) * 100, 2) AS lift_percent
    FROM conversion_rates c
    JOIN conversion_rates t
      ON c.country = t.country
     AND c."group" = 'control'
     AND t."group" = 'treatment'
)
SELECT * FROM pivoted
ORDER BY country;
