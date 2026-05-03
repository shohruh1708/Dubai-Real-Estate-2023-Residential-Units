


select * from output

-- i am selecting the columns that i will need to analyze and 
--inserting to new table named Dubai

select 
	instance_date,
	property_type_en,
	property_sub_type_en,
	property_usage_en, 
	building_name_en,
	project_name_en, 
	master_project_en,
	rooms_en, 
	has_parking, 
	procedure_area,
	actual_worth, 
	meter_sale_price,
	trans_group_en, 
	reg_type_en,
	area_id, 
	transaction_id
into Dubai
from output



-- here i am checking how many distinct bedroom types it has also 
--how many of them on this data, and can be seen it has offices, shops, gyms

select
rooms_en,count(*)
from Dubai
group by rooms_en
order by rooms_en




--- Right here i am creating another table where i will have only villas and units, 
-- and also rooms_en are not shops, sinle rooms, where it could 
--have consist on unit property_type_en


select * 
into Dubai_Residential
from Dubai
where 
property_type_en in ('villa', 'unit')
and 
property_usage_en = 'Residential'
and 
rooms_en is not null
and 
rooms_en not in('shop','Single Room')




--1. What is the average property price overall?

select
	AVG(actual_worth) as avg_price
from Dubai_Residential

;with w as
(
select *, 
	ROW_NUMBER() over (order by actual_worth desc) as rn, 
	count(*) over () as total_rows
from Dubai_Residential
)
select 
	AVG(actual_worth) as Median_Price
from w
where rn in ((total_rows + 1)/2, (total_rows + 2)/2)

-- So median price is 33% less then the Average price due to high price properties 
--like in World Islands, Palm Jumeirah, and Tecom Area



-- 2. What are the most expensive and cheapest locations?
;with filtering as
(
select 
	master_project_en, 
	AVG(actual_worth) as avg_per_location, 
	COUNT(*) as count_of_sale, 
	AVG(actual_worth) * COUNT(*) as score
from Dubai_Residential
where master_project_en is not null
group by master_project_en
)
select *
from filtering
where score = ( select MAX(score) from filtering)
or score = ( select MIN(score) from filtering)

-- Its very important what i am doing here
-- if i take only the avg by desc it would give me world island
--and Al Barari by highets avg_rate, although it wont be fair since they had only few transactions 
-- where Palm Jumerah had few thousand transactions. 
-- I say the Palm Jumeirah is one the most expensive locations

select 
	top 3
	master_project_en, 
	AVG(actual_worth) as avg_per_location, 
	COUNT(*) as count_of_sale
from Dubai_Residential
where master_project_en is not null
group by master_project_en
order by avg_per_location

-- And where International City Phase 3 is the cheapest, 
--where there were enought transactions to be judged



-- 3. Which projects capture the largest share of sales within each area?

;with filtering as
(
select 
	master_project_en,
	project_name_en,
	COUNT(*) as number_of_sale
from Dubai_Residential
where master_project_en is not null 
and project_name_en is not null
group by master_project_en, project_name_en
), ranking as
(
select *, 
	ROW_NUMBER() over (partition by master_project_en order by number_of_sale desc) as rn
from filtering
)
select * from ranking
where rn =1
order by number_of_sale desc

-- it show the list of projects in each area, 
--which have sold the most amount of properties


--4. How does property type affect price (apartment, villa, studio)?

select 
	property_sub_type_en,
	AVG(meter_sale_price) as avg_price_sq_mt
from Dubai_Residential
group by property_sub_type_en
order by avg_price_sq_mt desc

-- As can be seen Apartment prices are the highest per sq.mt, 
--then it followed by Villas and Townhouses, that is the way it should be actually, 
-- thats how it works every where in the world


--5. Which areas are the most “liquid” (high demand vs availability)?

;with area_sales as (
    select 
        master_project_en,
        COUNT(*) AS total_sales
    from Dubai_Residential
	where master_project_en is not null
    group by master_project_en
),
total as (
    select SUM(total_sales) AS total_market_sales
    from area_sales
)
select 
	top 5
    a.master_project_en,
    a.total_sales,
	total_market_sales,
    (a.total_sales * 100.0 / t.total_market_sales) AS market_share_pct
from area_sales a
cross join total t
order by total_sales desc;


--6. Are property prices increasing or decreasing over time?


;with comparing as
(
select 
	DATEFROMPARTS(year(instance_date),month(instance_date),1) as months,
	round(AVG(actual_worth), 0) as avg_price
from 
Dubai_Residential
group by DATEFROMPARTS(year(instance_date),month(instance_date),1)
), 
casing as
(
select *, 
	LAG(avg_price) over (order by months) as prv_avg
from comparing
)
select *, 
	case 
		when avg_price > prv_avg then 'Increasing'
		when prv_avg is null then 'None'
		else 'Decreasing' end as casing
from casing


-- It shows that thougout the year prices has been slightly fluctuating, 
--alghouth its remained in the same area, so significant increase or decrease has been detected. 



--7. Which locations have the highest number of listings (supply)?

select 
	top 5
	master_project_en,
	COUNT(*) as number_of_listings
from Dubai_Residential
where master_project_en is not null
group by master_project_en
order by number_of_listings desc

-- Jumeirah Village Circle is the winner by number of transactions




--⚖️ 8. Which areas look overvalued vs undervalued?

--(Compare price vs average benchmark)

;with comparing as
(
select *, 
	AVG(actual_worth) over () as avg_price_dubai, 
	AVG(actual_worth) over (partition by master_project_en) as avg_price_area
from Dubai_Residential
)
select distinct master_project_en from comparing
where avg_price_area < avg_price_dubai




--- Areas where avg prices are below then the total dubai avg_prices

--💵 9. What is the price per square meter by location?

select 
	master_project_en,
	AVG(meter_sale_price) as avg_price_sq_mt
from Dubai_Residential
group by master_project_en
order by avg_price_sq_mt desc

-- Again the world is wining by price per sq.mt but its very very unique peoject, 
--therefore i would say Palm jumeirah is the highest 



--10. Are there outliers in property prices?

--Detect luxury/extreme listings or data issues.

;with avg_prices as
(
select *,
AVG(actual_worth) over () as avg_price
from Dubai_Residential
)
select 
	COUNT(*) number_of_proerties
from avg_prices
where actual_worth > 50 * avg_price


-- we have got 32 properties that are 50 times more expensive then averge price in dubai, 
-- Some of them even 100 times more expensive, those are very very luxtuary and unique properties, 
-- that were sold mostly in Palm Jumeirah, highest prices property worth 500 mln AED, 
-- that is roughly 136 mln USD



--11. What is the distribution of property prices?

--(cheap, mid, luxury breakdown)

;with flagging as
(
SELECT 
    CASE 
        WHEN actual_worth < 1100000 THEN 'Cheap'
        WHEN actual_worth BETWEEN 1100000 AND 3670000 THEN 'Mid'
        ELSE 'Luxury'
    END AS price_category,
    COUNT(*) AS total_properties
FROM Dubai_Residential
GROUP BY 
    CASE 
        WHEN actual_worth < 1100000 THEN 'Cheap'
        WHEN actual_worth BETWEEN 1100000 AND 3670000 THEN 'Mid'
        ELSE 'Luxury'
    END
), percentage as
(
select *, 
	SUM(total_properties) over () as [total properties sold]
from flagging
)
select *, 
	cast(total_properties *1.0 / [total properties sold] * 100 as decimal(6,2)) as percentage_contribution
from percentage


-- it shows that Cheaper properties that are below 300K$ and Mid Level priced which are
-- between 300k$ and 1 mln $ are the roughly 90% of the market, 
--only 10% of properties are above 1 mln $


--💡 12. What are key insights or recommendations for buyers/investors?

--1. Market is mid-range driven
--•	Cheap: 41% | Mid: 49% | Luxury: 9.5% 
-- ~90% of transactions are non-luxury
-- Focus on mid-range for stable demand 
--2. High liquidity areas
--•	JVC: ~14.5% 
--•	Business Bay: ~8.9% 
--•	Dubai Marina: ~4.7% 
-- Highest transaction activity
-- Best areas for quick resale 

-- 3. Average price is misleading
--•	Avg: 2.02M AED 
--•	Median: 1.35M AED (~33% lower) 
-- Skewed by luxury deals
-- Use median for real market value 
--4. Property type pricing
--•	Apartments = highest price per sq.m 
-- Driven by location & demand
-- Apartments = liquidity, Villas = space 
--5. Market stability
--•	Minor monthly fluctuations, no clear trend 
-- Stable market in 2023
--Suitable for medium-term investment 

--6. Extreme luxury outliers
--•	32 properties > 50× avg price 
--•	Max ~500M AED (~136M USD) 
--Mostly ultra-luxury (e.g., Palm Jumeirah)
--Analyze separately 
-- 7. Undervalued opportunities
--•	Some areas priced below Dubai average 
--Potential investment zones
--Combine with demand + price/sq.m







