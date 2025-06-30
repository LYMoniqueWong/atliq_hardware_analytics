/*1. Provide the list of markets in which customer "Atliq Exclusive" operates its
business in the APAC region.*/

SELECT DISTINCT market
FROM dim_customer
WHERE customer = "Atliq Exclusive" AND region = "APAC";

/*2. What is the percentage of unique product increase in 2021 vs. 2020? The
final output contains these fields,
unique_products_2020
unique_products_2021
percentage_chg */

SELECT unique_products_2020, unique_products_2021,
ROUND(
(unique_products_2021 - unique_products_2020) / unique_products_2020 * 100
, 2) AS percentage_chg 
FROM
(SELECT COUNT(DISTINCT product_code) AS unique_products_2020
FROM fact_sales_monthly
WHERE fiscal_year = 2020
) AS n2020
CROSS JOIN
(SELECT COUNT(DISTINCT product_code) AS unique_products_2021
FROM fact_sales_monthly
WHERE fiscal_year = 2021
) AS n2021;

/* 3. Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains
2 fields,
segment
product_count */

SELECT segment, COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

/* 4. Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields,
segment
product_count_2020
product_count_2021
difference */ 

WITH segment_yearly AS (
SELECT d.segment, f.fiscal_year, COUNT(DISTINCT f.product_code) as product_count
FROM fact_sales_monthly f
JOIN dim_product d
ON f.product_code = d.product_code
WHERE fiscal_year IN (2020, 2021)
GROUP BY d.segment, f.fiscal_year
)
SELECT s2020.segment, s2020.product_count AS product_count_2020, s2021.product_count AS product_count_2021,
(s2021.product_count - s2020.product_count) AS difference
FROM segment_yearly s2020
JOIN segment_yearly s2021
ON s2020.segment = s2021.segment
AND s2020.fiscal_year = 2020
AND s2021.fiscal_year = 2021
ORDER BY difference DESC
LIMIT 1;

/* 5. Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields,
product_code
product
manufacturing_cost */ 

SELECT f.product_code, d.product, f.manufacturing_cost
FROM fact_manufacturing_cost f
JOIN dim_product d
ON f.product_code = d.product_code
WHERE f.manufacturing_cost = (
SELECT MAX(manufacturing_cost)
FROM fact_manufacturing_cost
) 
OR f.manufacturing_cost = (
SELECT MIN(manufacturing_cost)
FROM fact_manufacturing_cost
);

/* 6. Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
customer_code
customer
average_discount_percentage */

SELECT f.customer_code, d.customer, ROUND(AVG(pre_invoice_discount_pct), 2) AS average_discount_percentage
FROM fact_pre_invoice_deductions f
JOIN dim_customer d
ON f.customer_code = d.customer_code
WHERE fiscal_year = 2021 AND market = "India"
GROUP BY f.customer_code, d.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;

/* 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . This 
analysis helps to get an idea of low and high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount */

SELECT EXTRACT(MONTH FROM fsm.date) AS month, EXTRACT(YEAR FROM fsm.date) AS year,
ROUND(SUM(fgp.gross_price * fsm.sold_quantity), 2) AS gross_sales_amount
FROM fact_sales_monthly fsm
JOIN dim_customer dc
ON fsm.customer_code = dc.customer_code
JOIN fact_gross_price fgp
ON fgp.product_code = fsm.product_code AND fgp.fiscal_year = fsm.fiscal_year
WHERE customer = "Atliq Exclusive"
GROUP BY year, month
ORDER BY year, month;

/* 8. In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the 
total_sold_quantity,
Quarter
total_sold_quantity */

WITH sales_with_quarter AS (
SELECT sold_quantity,
CASE
WHEN EXTRACT(MONTH FROM date) BETWEEN 9 AND 11 THEN 'Q1'
WHEN EXTRACT(MONTH FROM date) IN (12, 1, 2) THEN 'Q2'
WHEN EXTRACT(MONTH FROM date) BETWEEN 3 AND 5 THEN 'Q3'
WHEN EXTRACT(MONTH FROM date) BETWEEN 6 AND 8 THEN 'Q4'
END AS quarter
FROM fact_sales_monthly 
WHERE fiscal_year = 2020
)
SELECT quarter, SUM(sold_quantity) AS total_sold_quantity
FROM sales_with_quarter
GROUP BY quarter
ORDER BY total_sold_quantity DESC
LIMIT 1;

/* 9. Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
channel
gross_sales_mln
percentage */

WITH channel_sales AS (
SELECT dc.channel, SUM(fsm.sold_quantity * fgp.gross_price) AS gross_sales
FROM fact_sales_monthly fsm
JOIN fact_gross_price fgp
ON fsm.product_code = fgp.product_code AND fsm.fiscal_year = fgp.fiscal_year
JOIN dim_customer dc
ON fsm.customer_code = dc.customer_code
WHERE fsm.fiscal_year = 2021
GROUP BY dc.channel
), total_sales AS (
SELECT SUM(gross_sales) AS total_sales FROM channel_sales
) 
SELECT cs.channel, ROUND(cs.gross_sales/1e6, 2) AS gross_sales_mln, 
ROUND(cs.gross_sales / ts.total_sales * 100, 2) AS percentage
FROM channel_sales cs
CROSS JOIN total_sales ts
ORDER BY cs.gross_sales  DESC
LIMIT 1;

/* 10. Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these
fields,
division
product_code
product
total_sold_quantity
rank_order */

WITH prod_total AS (
SELECT dp.division, dp.product_code, dp.product,
SUM(fsm.sold_quantity) AS total_sold_quantity
FROM dim_product dp
JOIN fact_sales_monthly fsm
ON dp.product_code = fsm.product_code
WHERE fsm.fiscal_year = 2021
GROUP BY dp.division, dp.product_code, dp.product
), ranked AS (
SELECT division, product_code, product, total_sold_quantity,
ROW_NUMBER () OVER (
PARTITION BY division
ORDER BY total_sold_quantity DESC
) AS rank_order
FROM prod_total
)
SELECT division, product_code, product, total_sold_quantity, rank_order
FROM ranked
WHERE rank_order <= 3
ORDER BY division, rank_order;







