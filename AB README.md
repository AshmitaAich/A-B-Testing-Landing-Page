# **Landing Page A/B Test – Conversion Rate Analysis**



Author: Ashmita Aich



Description: This project analyzes the performance of a landing page A/B test to determine if a new page improves user conversion. The

dataset includes

\- Group assignments (control vs treatment)

\- Landing page variants

\- Conversion outcomes

\- Country information



Datasets:

ab_data- User group assignments and conversion data

countries- Country mapping of users



Data was imported into PostgreSQL using pgAdmin.

The cleaned dataset was used for Tableau dashboard visualizations.



Tools Used:

PostgreSQL (for SQL querying and data preparation)

Tableau (for visualization)





### Data Cleaning Steps:



### 1\. Check for inconsistent group–landing page combinations



```sql
SELECT *

FROM ab_data

WHERE ("group" = 'control' AND landing_page != 'old_page')

   OR ("group" = 'treatment' AND landing_page != 'new_page');
```



### 2\. Delete mismatched group–page combinations



```sql
DELETE FROM ab_data

WHERE ("group" = 'control' AND landing_page != 'old_page')

   OR ("group" = 'treatment' AND landing_page != 'new_page');
```



### 3\. Check for duplicate user_ids in ab_data



```sql
SELECT user_id, COUNT(*)

FROM ab_data

GROUP BY user_id

HAVING COUNT(*) > 1;
```



### 4\. Remove duplicate user_ids in ab_data



```sql
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
```



### 5\. Check for duplicate user_ids in countries



```sql
SELECT user_id, COUNT(*)

FROM countries

GROUP BY user_id

HAVING COUNT(*) > 1;
```



### 6\. Remove duplicate user_ids in countries



```sql
WITH ranked_countries AS (

    SELECT ctid,

           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY country) AS rn

    FROM countries

)

DELETE FROM countries

WHERE ctid IN (

    SELECT ctid FROM ranked_countries WHERE rn > 1

);
```





### Data Preparation (Joining Tables):

### 

### Create a view combining ab_data and countries

### 

```sql
CREATE VIEW ab_cleaned AS

SELECT a.*, c.country

FROM ab_data a

LEFT JOIN countries c ON a.user_id = c.user_id;
```





### Data Analysis Queries:



### 1\. Overall Conversion Rate by Group



```sql
SELECT "group",

       COUNT(*) AS total_users,

       SUM(converted) AS total_converted,

       ROUND((AVG(converted::float) * 100)::numeric, 2) AS conversion_rate

FROM ab_cleaned

GROUP BY "group";
```



### 2\. Absolute Difference in Conversion Rates



```sql
WITH conversion_rates AS (

    SELECT

        "group",

        ROUND((AVG(converted::float) \* 100)::numeric, 2) AS conversion_rate

    FROM ab_cleaned

    GROUP BY "group"

)



SELECT

    ABS(

        MAX(CASE WHEN "group" = 'treatment' THEN conversion_rate END) -

        MAX(CASE WHEN "group" = 'control' THEN conversion_rate END)

    ) AS difference_in_conversion_rate

FROM conversion_rates;
```



### 3\. Statistical Significance (Z-test)



```sql
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
```



### 4\. Conversion Rate by Country



```sql
SELECT country,

       COUNT(*) AS users,

       ROUND((AVG(converted::float) * 100)::numeric, 2) AS conversion_rate

FROM ab_cleaned

GROUP BY country

ORDER BY conversion_rate DESC;
```



### 5\. Conversion Rate by Country and Group



```sql
SELECT country,

       "group",

       COUNT(*) AS total_users,

       SUM(converted) AS total_converted,

       ROUND((AVG(converted::float) * 100)::numeric, 2) AS conversion_rate

FROM ab_cleaned

GROUP BY country, "group"

ORDER BY country, "group";
```



### 6\. Overall Lift in Conversion



```sql
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
```



### 7\. Country-wise Lift Calculation



```sql
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
```







### TABLEAU DASHBOARD



The dashboard provides a comprehensive visual summary of the A/B testing analysis using several key elements.





### KPI Cards: Display essential metrics at a glance, including-



Control Conversion Rate: 12.04%

Treatment Conversion Rate: 11.88%

Overall Lift %: -1.31%

P-Value: 0.19

Significance Status: ❌ Not Significant





### Conversion Rate by Group (Bar Chart):

### 

A side-by-side comparison of the two groups, showing a slightly higher conversion in the control group.



### Conversion Rate by Country (Bubble Chart):



Country-level breakdown reveals variation in performance across UK, US, and CA.



### Country-wise Slope Chart (Control vs Treatment):



Highlights subtle differences in conversion rates between groups for each country. The slope shows where the treatment group under or

over-performed relative to control.



### A/B Test Analysis Summary (Text Box):



Provides an executive summary of the test outcome. Includes insights such as

-The UK audience showed a minor positive lift.

-However, the overall difference was not statistically significant.







### KEY INSIGHTS



* The control page slightly outperformed the treatment page in conversion rate (12.04% vs. 11.88%).
* The observed difference was not statistically significant (p = 0.19), indicating no strong evidence to adopt the new design.
* UK users showed a small positive lift, suggesting scope for localized A/B testing in future campaigns.

### 

### RECOMMENDATION:

### 

Retain the current (control) page until further segmented testing yields stronger insights.







### CONCLUSION



The A/B test results do not provide strong enough evidence to roll out the new landing page universally. However, localized improvements

or further testing may yield better outcomes.















### Tableau Public Link

### 

https://public.tableau.com/views/ABTestingDashboard_17537135519050/ABTestingDashboard?:language=en-US\&:sid=\&:redirect=auth\&:display_count=n\&:origin=viz_share_link

