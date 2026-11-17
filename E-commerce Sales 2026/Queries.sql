					-- Profitability and Margin --
-- 1. Which products, categories, subcategories, and brands generate high revenue but low or negative profit_margin_percent? 
WITH product_summary AS(
	SELECT
		product_id,
		product_category,
		product_subcategory,
		brand,
	SUM(net_revenue) AS total_revenue,
	ROUND(AVG(profit_margin_percent), 2) AS avg_margin,
	COUNT(*) AS order_count
	FROM orders
	GROUP BY product_id, product_category, product_subcategory, brand
)
SELECT
	product_id,
	product_category,
	product_subcategory,
	brand,
	total_revenue,
	avg_margin,
	order_count
FROM product_summary
WHERE total_revenue > (SELECT AVG(total_revenue) FROM product_summary)
	AND avg_margin < (SELECT AVG(avg_margin) FROM product_summary)
ORDER BY total_revenue DESC
LIMIT 20;

WITH product_summary AS(
	SELECT
		--product_id,
		product_category,
		product_subcategory,
		--brand,
	SUM(net_revenue) AS total_revenue,
	ROUND(AVG(profit_margin_percent), 2) AS avg_margin,
	COUNT(*) AS order_count
	FROM orders
	GROUP BY product_category, product_subcategory
)
SELECT
	--product_id,
	product_category,
	product_subcategory,
	--brand,
	total_revenue,
	avg_margin,
	order_count
FROM product_summary
WHERE total_revenue > (SELECT AVG(total_revenue) FROM product_summary)
	AND avg_margin < (SELECT AVG(avg_margin) FROM product_summary)
ORDER BY total_revenue DESC

-- 2. Which Product_Category is most discount-dependent (highest average Discount_Percent) — and is that category also among the least profitable?
SELECT
    customer_segment, membership_status,
    AVG(order_amount) AS avg_order_amount,
    SUM(profit_amount) AS total_profit,
    AVG(profit_amount) AS avg_profit_amount,
    ROUND(AVG(profit_margin_percent),2) AS avg_margin,
    COUNT(*) AS order_count
FROM orders
GROUP BY customer_segment, membership_status
ORDER BY avg_margin DESC;
 
-- Q3: Warehouse region - best/worst margin after shipping cost
WITH region_summary AS (
    SELECT
        warehouse_region,
        SUM(profit_amount) AS total_profit,
        SUM(shipping_cost) AS total_shipping_cost,
        SUM(order_amount) AS total_order_amount,
        AVG(profit_margin_percent) AS avg_raw_margin_pct,
        COUNT(*) AS order_count
    FROM orders
    GROUP BY warehouse_region
)
SELECT
    warehouse_region, total_profit, total_shipping_cost,
    (total_profit - total_shipping_cost) AS adjusted_profit,
    avg_raw_margin_pct,
    ROUND(((total_profit - total_shipping_cost) / total_order_amount) * 100, 2) AS adjusted_margin_pct,
    order_count
FROM region_summary
ORDER BY adjusted_margin_pct ASC;

                 -- Discount & Coupon Effectiveness --
-- Q4: Discount band vs margin (does margin turn negative?)
SELECT
    discount_band,
    ROUND(AVG(discount_percent), 2) AS avg_dis_pct,
    ROUND(AVG(profit_margin_percent), 2) AS avg_pft_mgn_pct,
    MIN(profit_margin_percent) AS min_profit_mgn_pct,
    COUNT(*) AS total_orders
FROM orders
GROUP BY discount_band
ORDER BY avg_dis_pct ASC;
 
-- Margin floor check
SELECT COUNT(*) FROM orders WHERE profit_margin_percent = 3;
 
-- Floor hits by discount band, with percentage
WITH floor_counts AS (
    SELECT discount_band, COUNT(*) AS count_at_floor
    FROM orders WHERE profit_margin_percent = 3
    GROUP BY discount_band
),
total_counts AS (
    SELECT discount_band, COUNT(*) AS total_orders
    FROM orders GROUP BY discount_band
)
SELECT t.discount_band, f.count_at_floor, t.total_orders,
    ROUND((f.count_at_floor::NUMERIC / t.total_orders) * 100, 2) AS pct_at_floor
FROM total_counts t
JOIN floor_counts f ON t.discount_band = f.discount_band
ORDER BY t.discount_band;
 
-- Q5: Coupon usage - profit vs non-coupon orders
SELECT
    coupon_used,
    COUNT(*) AS order_count,
    AVG(order_amount) AS avg_order_amount,
    AVG(profit_amount) AS avg_profit_amount,
    AVG(profit_margin_percent) AS avg_margin_pct,
    SUM(profit_amount) AS total_profit
FROM orders
GROUP BY coupon_used;

					-- Returns & Product Quality --
-- Q6: Most discount-dependent category, also least profitable?
SELECT
    product_category,
    ROUND(AVG(discount_amount), 2) AS avg_discount,
    ROUND(AVG(discount_percent), 2) AS avg_disc_pct,
    ROUND(AVG(profit_margin_percent), 2) AS avg_margin,
    SUM(net_revenue) AS total_revenue,
    COUNT(*) AS order_count
FROM orders
GROUP BY product_category
ORDER BY avg_disc_pct DESC;
 
-- Q7: Return rate by category/brand, correlation with review rating
-- Category level
SELECT
    product_category,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN is_returned THEN 1 ELSE 0 END) AS returned_orders,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct,
    ROUND(AVG(review_rating), 2) AS avg_review_rating
FROM orders
GROUP BY product_category
ORDER BY return_rate_pct DESC;
 
-- Category + brand level
SELECT
    product_category, brand,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN is_returned THEN 1 ELSE 0 END) AS returned_orders,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct,
    ROUND(AVG(review_rating), 2) AS avg_review
FROM orders
GROUP BY product_category, brand
ORDER BY return_rate_pct DESC, total_orders DESC;
 
-- Q8: Discount percent vs return likelihood
SELECT
    discount_band,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN is_returned THEN 1 ELSE 0 END) AS returned_orders,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY discount_band
ORDER BY discount_band;
 
-- Q9: Delivery days vs return rate
SELECT
    delivery_band,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN is_returned THEN 1 ELSE 0 END) AS returned_orders,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY delivery_band
ORDER BY delivery_band;

					-- Shipping & Fulfillment Cost --
-- Q10: Shipping method/region - highest shipping cost ratio
SELECT
    shipping_method, warehouse_region,
    COUNT(*) AS total_orders,
    ROUND(AVG(shipping_cost), 2) AS avg_shipping_cost,
    ROUND(AVG(order_amount), 2) AS avg_order_amount,
    ROUND(AVG(shipping_cost / order_amount) * 100, 2) AS avg_shipping_cost_ratio_pct
FROM orders
GROUP BY shipping_method, warehouse_region
ORDER BY avg_shipping_cost_ratio_pct DESC;
 
-- Q11: Delivery days vs shipping cost vs margin vs review rating
SELECT
    shipping_method,
    COUNT(*) AS total_orders,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(shipping_cost), 2) AS avg_shipping_cost,
    ROUND(AVG(shipping_cost / order_amount) * 100, 2) AS avg_shipping_cost_ratio_pct,
    ROUND(AVG(profit_margin_percent), 2) AS avg_margin_pct,
    ROUND(AVG(review_rating), 2) AS avg_review_rating
FROM orders
GROUP BY shipping_method
ORDER BY avg_delivery_days ASC;

				-- Customer & Channel Value --
-- Q12: Traffic source - CLV and return rate
SELECT
    traffic_source,
    COUNT(*) AS total_orders,
    ROUND(AVG(customer_lifetime_value), 2) AS avg_clv,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY traffic_source
ORDER BY avg_clv DESC;
 
-- Q13: Device type - discount usage 
SELECT
    device_type,
    ROUND(AVG(discount_percent), 2) AS avg_discount_pct,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY device_type;


				-- Seasonality & Timing --
-- Q14: Payment method - order amount / return rate
SELECT
    payment_method,
    ROUND(AVG(order_amount), 2) AS avg_order_amount,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY payment_method;
 
-- Q15: Holiday season - discount/margin spike?
SELECT
    holiday_season,
    COUNT(*) AS total_orders,
    ROUND(AVG(discount_percent), 2) AS avg_discount_pct,
    ROUND(AVG(profit_margin_percent), 2) AS avg_pft_margin
FROM orders
GROUP BY holiday_season;
 
-- Q16: Season - return rate (overall, and Fashion-specific)
SELECT
    season,
    COUNT(*) AS total_orders,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY season
ORDER BY return_rate_pct DESC;
 
-- Every category x season
SELECT
    season, product_category,
    COUNT(*) AS total_orders,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY season, product_category
ORDER BY return_rate_pct DESC;

 				-- Executive/Action-Oriented --
-- Q17: High_Value_Order profile - category + discount band + channel
SELECT
    product_category, discount_band, traffic_source,
    COUNT(*) AS total_orders,
    ROUND((SUM(CASE WHEN high_value_order = 'Yes' THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS high_value_rate_pct,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY product_category, discount_band, traffic_source
HAVING COUNT(*) >= 30
ORDER BY high_value_rate_pct DESC, return_rate_pct ASC;
 
-- Q18: Profit retained if 3 least-profitable subcategories dropped
WITH subcategory_profit AS (
    SELECT product_subcategory, SUM(profit_amount) AS total_profit, COUNT(*) AS total_orders
    FROM orders GROUP BY product_subcategory
),
ranked AS (
    SELECT *, RANK() OVER (ORDER BY total_profit ASC) AS profit_rank FROM subcategory_profit
)
SELECT product_subcategory, total_profit, total_orders, profit_rank
FROM ranked ORDER BY profit_rank ASC LIMIT 3;
 
-- Fill in actual subcategory names from above result
SELECT
    SUM(profit_amount) AS total_profit_all,
    SUM(CASE WHEN product_subcategory NOT IN ('Non-Fiction','Education','Comics') THEN profit_amount ELSE 0 END) AS profit_if_dropped,
    ROUND((SUM(CASE WHEN product_subcategory NOT IN ('Non-Fiction','Education','Comics') THEN profit_amount ELSE 0 END)::NUMERIC / SUM(profit_amount)) * 100, 2) AS pct_profit_retained
FROM orders;

 				-- ORDERS STATUS SUMMARY --
-- Q19: Order status breakdown
SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND((COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM orders)) * 100, 2) AS pct_of_all_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;
 
-- Q20: Cancellation rate by category/brand
SELECT
    product_category, brand,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status ILIKE 'Cancel%' THEN 1 ELSE 0 END) AS canceled_orders,
    ROUND((SUM(CASE WHEN order_status ILIKE 'Cancel%' THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS cancellation_rate_pct
FROM orders
GROUP BY product_category, brand
ORDER BY cancellation_rate_pct DESC, total_orders DESC;
 
-- Q21: Cancellation rate by payment method
SELECT
    payment_method,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status ILIKE 'Cancel%' THEN 1 ELSE 0 END) AS canceled_orders,
    ROUND((SUM(CASE WHEN order_status ILIKE 'Cancel%' THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS cancellation_rate_pct
FROM orders
GROUP BY payment_method
on_rate_pct DESC
-- Q22: Revenue/profit lost to cancellations vs returns
-- Overlap check
SELECT COUNT(*) FROM orders WHERE order_status ILIKE 'Cancel%' AND is_returned = true;
 
-- Returned totals
SELECT COUNT(*) AS order_count, SUM(order_amount) AS lost_revenue, SUM(profit_amount) AS lost_profit
FROM orders WHERE is_returned = true;
 
-- Canceled totals
SELECT COUNT(*) AS order_count, SUM(order_amount) AS lost_revenue, SUM(profit_amount) AS lost_profit
FROM orders WHERE order_status ILIKE 'Cancel%';

 			-- Delivery & Fulfillment --
-- Q23: Category/shipping method - longest delivery time
SELECT
    product_category, shipping_method,
    COUNT(*) AS total_orders,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    SUM(CASE WHEN delivery_band = '8+ days' THEN 1 ELSE 0 END) AS orders_8plus_days
FROM orders
GROUP BY product_category, shipping_method
ORDER BY avg_delivery_days DESC;
 
-- Q24: Warehouse region vs delivery days (controlling for shipping method)

SELECT warehouse_region, COUNT(*) AS total_orders, ROUND(AVG(delivery_days), 2) AS avg_delivery_days
FROM orders GROUP BY warehouse_region ORDER BY avg_delivery_days DESC;
 
SELECT
    shipping_method, warehouse_region,
    COUNT(*) AS total_orders,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days
FROM orders
GROUP BY shipping_method, warehouse_region
ORDER BY shipping_method, avg_delivery_days DESC;

 					-- Time Trends --
-- Q25: Month-over-month / quarter-over-quarter trend
SELECT DISTINCT year FROM orders ORDER BY year;
 
SELECT
    year, month,
    COUNT(*) AS total_orders,
    SUM(net_revenue) AS total_revenue,
    ROUND(AVG(profit_margin_percent), 2) AS avg_margin_pct
FROM orders GROUP BY year, month ORDER BY year, month;
 
SELECT
    year, quarter,
    COUNT(*) AS total_orders,
    SUM(net_revenue) AS total_revenue,
    ROUND(AVG(profit_margin_percent), 2) AS avg_margin_pct
FROM orders GROUP BY year, quarter ORDER BY year, quarter;
 
-- Q26: Day of week effect
SELECT
    day_of_week,
    COUNT(*) AS total_orders,
    ROUND(AVG(order_amount), 2) AS avg_order_value,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY day_of_week
ORDER BY total_orders DESC;

					-- Customer Demographics  --
-- Q27: Customer age vs order value, discount, return rate
SELECT
    CASE
        WHEN customer_age < 25 THEN 'Under 25'
        WHEN customer_age BETWEEN 25 AND 34 THEN '25-34'
        WHEN customer_age BETWEEN 35THEN '35-44'
       _age BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END AS age_band,
    COUNT(*) AS total_orders,
    ROUND(AVG(order_amount), 2) AS avg_order_value,
    ROUND(AVG(discount_percent), 2) AS avg_discount_pct,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY age_banR BY age_band
-- Q28: Gender - category preference, order value, return rate
SELECT
    customer_gender,
    COUNT(*) AS total_orders,
    ROUND(AVG(order_amount), 2) AS avg_order_value,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY customer_gender;
 
SELECT
    customer_gender, product_category,
    COUNT(*) AS total_orders,
    ROUND((COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (PARTITION BY customer_gender)) * 100, 2) AS pct_of_gender_orders
FROM orders
GROUP BY customer_gender, product_category
ORDER BY customer_gender, pct_of_gender_orders DESC;
 
-- Q29: Country - revenue and margin
SELECT
    country,
    COUNT(*) AS total_orders,
    SUM(net_revenue) AS total_revenue,
    ROUND(AVG(profit_margin_percent), 2) AS avg_margin_pct
FROM orders
GROUP BY country
ORDER BY total_revenue DESC;

						-- Order Composition --
-- Q30: Order quantity vs discount usage / return likelihood
SELECT
    quantity,
    COUNT(*) AS total_orders,
    ROUND(AVG(discount_percent), 2) AS avg_discount_pct,
    ROUND((SUM(CASE WHEN is_returned THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2) AS return_rate_pct
FROM orders
GROUP BY quantity
ORDER BY quantity;
	