# 📊 Customer-Data-Cleaning-and-Purchase-Analysis

## 🧾 Project Overview
This project demonstrates an end-to-end SQL data cleaning and business analysis workflow using a messy dataset.  
The goal is to transform raw, inconsistent data into a clean analytical dataset and extract meaningful business insights such as customer behavior, revenue trends, and country-wise performance.

---

## 🎯 Problem Definition

The business has raw customer transaction data riddled with inconsistencies — duplicate records, malformed emails, inconsistent country naming, mixed date formats, and invalid spending values. Before any reliable analysis of customer behavior or revenue can happen, this data needs to be cleaned and validated.

**Stakeholder question:** *How much revenue and customer activity can we confidently report, and which markets are actually driving our business?*

---

## 🗂️ Dataset
## Dataset Information
- **Source:** The data set used in this project was generated using DeepSeek AI(a generative artificial intelligence platform)  for portfolio purpose. All data is synthetic and does not represent real individuals.
- The raw data set has 183 rows including header row, duplicates rows and blank rows and the following six columns
Customer_ID

Customer_Name

Email

Country

Last_Purchase_Date

Total_Spent($)

---


```text
START ─────────────────────────────────────────────

Customer-Data-Cleaning-and-Purchase-Analysis/
│
├── data/
│   ├── raw/
│   │   ├── data-1780491514061.csv
│   │
│   └── clean/
│       ├── data-1780491886428.csv
│
├── Analysis/
│   ├── top_25_countries_by_total_spending.csv
│
├── SQL/
│   └── Customer Data Cleaning and Purchase Analysis.sql
│
└── README.md

END ─────────────────────────────────────────────
``` 
---

# 🧹 Step-by-Step Data Cleaning Process

---

## 🔹 Step 1: Create Raw Table
We create a raw table where all columns are stored as TEXT to preserve original messy data.

```sql
create table customers_sales_raw(
	Customer_ID text,
	Customer_Name text,
	Email text,
	Country text,
	Last_Purchase_Date text,
	"Total_Spent($)" text
);

select * from customers_sales_raw;
```

## Raw Data

[View Raw Dataset](data/raw/data-1780491514061.csv)
---

## 🔹 Step 2: Create Working Copy
We create a working copy so the original raw data remains unchanged.

```sql
create table customers_sales_clean as
select * from customers_sales_raw;
```

---

## 🔹 Step 3: Remove Blank Rows
Identify and delete fully empty rows.

```sql
-- Check blank rows
SELECT *
FROM customers_sales_clean
WHERE Customer_ID = 'NULL';

-- Delete blank rows
delete from customers_sales_clean
WHERE Customer_ID = 'NULL';
```

---

## 🔹 Step 4: Remove Duplicates
We detect duplicates using `ROW_NUMBER()` and remove them.

```sql
-- Detect duplicates
select * from (
    select *,
           row_number() over(partition by Customer_Id) as rn
    from customers_sales_clean
) t
where rn > 1;

-- Delete duplicates
DELETE FROM customers_sales_clean
WHERE ctid IN (
    SELECT ctid
    FROM (
        SELECT ctid,
               ROW_NUMBER() OVER(
                   PARTITION BY customer_id
               ) AS rn
        FROM customers_sales_clean
    ) t
    WHERE rn > 1
);
```

---

## 🔹 Step 5: Clean Customer Names
We remove extra spaces and standardize naming format.

```sql
-- Checking Leading & Trailing Spaces
select Customer_Name 
from customers_sales_clean
where Customer_Name <> trim(Customer_Name);

-- Remove Leading & Trailing Spaces
update customers_sales_clean
set Customer_Name = trim(Customer_Name);

-- Standardize Case
update customers_sales_clean
set Customer_Name = Initcap(lower(Customer_Name));
```

---

## 🔹 Step 6: Clean Emails
We fix formatting issues and missing values.

```sql
-- Standardize case and strip leading/trailing spaces
UPDATE customers_sales_clean
SET email = LOWER(TRIM(email));

-- Wipe out ALL internal spaces inside the emails 
-- (This instantly fixes 'email .com', 'email com', and 'davis @.com')
UPDATE customers_sales_clean
SET email = REPLACE(email, ' ', '')
WHERE email LIKE '% %';

-- Clean up double punctuation marks
-- (Fixes 'email..com' and '@@email.com')
UPDATE customers_sales_clean
SET email = REPLACE(REPLACE(email, '@@', '@'), '..', '.');

-- Fix specific missing dots or broken patterns left behind
-- Fixes 'emailcom' -> 'email.com'
UPDATE customers_sales_clean
SET email = REPLACE(email, 'emailcom', 'email.com')
WHERE email LIKE '%emailcom%';

-- Fixes '@.com' -> '@email.com' (like in mia.davis@.com after spaces were removed)
UPDATE customers_sales_clean
SET email = REPLACE(email, '@.com', '@email.com')
WHERE email LIKE '%@.com';

-- Fix any text strings that literally say 'null' or are completely blank
UPDATE customers_sales_clean
SET email = 'No_Email_provided'
WHERE email IS NULL 
   OR email = 'null' 
   OR email = '';

-- Fix trailing dots left behind from space removal (e.g., 'email.' -> 'email.com')
UPDATE customers_sales_clean
SET email = email || 'com'
WHERE email LIKE '%@email.';
```

---

## 🔹 Step 7: Standardize Country Names

```sql
-- Wipe extra spaces and lower everything to make matching simple
UPDATE customers_sales_clean 
SET country = LOWER(TRIM(country));

-- Standardize Standalone Abbreviations (Forces them to uppercase)
UPDATE customers_sales_clean SET country = 'USA' WHERE country IN ('usa', 'u.s.a', 'u.s.a.');
UPDATE customers_sales_clean SET country = 'UK'  WHERE country IN ('uk', 'u.k', 'u.k.');
UPDATE customers_sales_clean SET country = 'UAE' WHERE country IN ('uae');

-- Handle Missing/String NULL Countries
UPDATE customers_sales_clean
SET country = 'Unknown'
WHERE country IS NULL OR country = 'null' OR country = '';

-- Capitalize regular countries 
-- (CRITICAL FIX: Changed to uppercase 'USA','UK','UAE' to match Step 2!)
UPDATE customers_sales_clean
SET country = INITCAP(country)
WHERE country NOT IN ('USA', 'UK', 'UAE', 'Unknown')
  AND country NOT LIKE '%/%';

-- Capitalize full country combinations (e.g., 'china/japan' -> 'China/Japan')
UPDATE customers_sales_clean
SET country = INITCAP(country)
WHERE country LIKE '%/%';

-- Clean up abbreviation fragments globally (Forces 'Usa' -> 'USA' everywhere)
-- (CRITICAL FIX: Removed WHERE country LIKE '%/%' so it fixes standalone rows too!)
UPDATE customers_sales_clean
SET country = REGEXP_REPLACE(
                REGEXP_REPLACE(
                  REGEXP_REPLACE(country, 'usa', 'USA', 'i'), 
                'uk', 'UK', 'i'),
              'uae', 'UAE', 'i');

-- Specific literal cleanup for dotted slashes (Fixes 'U.S.A/U.K' -> 'USA/UK')
UPDATE customers_sales_clean
SET country = REPLACE(REPLACE(country, 'U.S.A', 'USA'), 'U.K', 'UK')
WHERE country LIKE '%/%';
```
> **Note on approach:** The email and country cleaning logic above was written to target the specific error patterns found in this dataset (e.g., `emailcom`, `u.s.a`, missing dots). This works well here, but a production-scale cleaning pipeline would typically use more generalized validation.

---

## 🔹 Step 8: Standardize Dates

```sql
-- 1. First, handle any literal 'NULL' strings so they don't break the conversions
UPDATE customers_sales_clean
SET Last_Purchase_Date = NULL
WHERE Last_Purchase_Date = 'NULL' OR TRIM(Last_Purchase_Date) = '';

-- 2. Update all formats in the existing column to a unified ISO text format (YYYY-MM-DD)
UPDATE customers_sales_clean
SET Last_Purchase_Date = CASE 
    -- Handle MM/DD/YYYY (e.g., 2/23/2024 in image_74aea3.png)
    WHEN Last_Purchase_Date ~ '^\d{1,2}/\d{1,2}/\d{4}$' 
        THEN TO_CHAR(TO_DATE(Last_Purchase_Date, 'MM/DD/YYYY'), 'YYYY-MM-DD')

    -- Handle DD-MM-YYYY (e.g., 15-02-2024 in image_745c68.png)
    WHEN Last_Purchase_Date ~ '^\d{1,2}-\d{1,2}-\d{4}$' 
        THEN TO_CHAR(TO_DATE(Last_Purchase_Date, 'DD-MM-YYYY'), 'YYYY-MM-DD')

    -- Handle Text Dates (e.g., 5-Mar-24 or 1-Jan-24 in image_745cc5.png)
    WHEN Last_Purchase_Date ~ '^\d{1,2}-[A-Za-z]{3}-\d{2}$' 
        THEN TO_CHAR(TO_DATE(Last_Purchase_Date, 'DD-MON-YY'), 'YYYY-MM-DD')
    
    ELSE Last_Purchase_Date
END
WHERE Last_Purchase_Date IS NOT NULL;

-- 3. Now alter the column type directly to a real DATE type
ALTER TABLE customers_sales_clean
ALTER COLUMN Last_Purchase_Date TYPE DATE 
USING Last_Purchase_Date::DATE;
```

---

## 🔹 Step 9: Clean Total Spent

```sql
-- 1. Remove Dollar Signs, Commas, and leading/trailing spaces
UPDATE customers_sales_clean
SET "Total_Spent($)" = TRIM(REPLACE(REPLACE("Total_Spent($)", '$', ''), ',', ''));

-- 2. Convert text flags ('N/A', 'NULL', '#VALUE') directly to database NULLs
UPDATE customers_sales_clean 
SET "Total_Spent($)" = NULL
WHERE UPPER(TRIM("Total_Spent($)")) IN ('N/A', 'NULL', '#VALUE') 
   OR "Total_Spent($)" = '';

-- 3. Safely convert the column to a clean NUMERIC data type
ALTER TABLE customers_sales_clean
ALTER COLUMN "Total_Spent($)" TYPE NUMERIC(12,2)
USING "Total_Spent($)"::NUMERIC(12,2);
```
---

## 🔹 Step 10: Data Quality Flag

```sql
-- Step 10a: Create a Unified Data Quality Flag Column
ALTER TABLE customers_sales_clean
ADD COLUMN Data_Quality_Flag TEXT;

-- Step 10b: Populate the flag based on both Date and Spent columns
UPDATE customers_sales_clean
SET Data_Quality_Flag = CASE
                            -- Case 1: Both columns are missing data
                            WHEN Last_Purchase_Date IS NULL AND "Total_Spent($)" IS NULL 
                                THEN 'Missing Date & Total Spent'
                            
                            -- Case 2: Only the date is missing
                            WHEN Last_Purchase_Date IS NULL 
                                THEN 'Missing Purchase Date'
                            
                            -- Case 3: Only the total spent is missing
                            WHEN "Total_Spent($)" IS NULL 
                                THEN 'Missing Total Spent'
                            
                            -- Case 4: Everything looks good!
                            ELSE 'OK'
                        END;
```

## Clean Data

[View Clean Dataset](data/clean/data-1780491886428.csv)
---

# 📊 Business Analysis

---

## Total Customers
```sql
select count(*) as Total_Customers 
from customers_sales_clean;
```

---

## Zero Purchase Customers
```sql
select count(*) as zero_purchases 
from customers_sales_clean 
where "Total_Spent($)" is null;
```

---

## Percentage of No Purchases
```sql
select round(100.0 * count(*) filter(where "Total_Spent($)" is null) / count(*), 2) as Percentage_Of_No_Purchase
from customers_sales_clean;
```

---

## Total Revenue
```sql
select sum("Total_Spent($)") as Total_Spending 
from customers_sales_clean;
```

---

## Average Spend per Customer
```sql
select round(avg(coalesce("Total_Spent($)", 0)), 2) as Average_Spend 
from customers_sales_clean;
```

---

## Top Revenue Country
```sql
select Country,
       sum("Total_Spent($)") as revenue
from customers_sales_clean
group by Country
order by revenue desc
limit 1;
```

---

## Revenue by Country
```sql
select Country,
       sum("Total_Spent($)") as Total_Spending
from customers_sales_clean
group by Country
order by Total_Spending desc
limit 25;
```

## top_25_countries_by_total_spending

[View top_25_countries_by_total_spending](Analysis/top_25_countries_by_total_spending.csv)
---

### Insights Generated
- 2.3% of Customers (4 Customers) have no purchases, highlighting minor data quality issues in the raw dataset. These entries were flagged as missing in the cleaned dataset to ensure accurate calculations in analysis.
- While the top country generates $71,500 in total spending, the combined spending of other countries is significantly higher at around $1,447,800, showing that overall revenue is largely driven by multiple markets rather than a single country.
- The USA has the highest total spent, but the other top countries also contribute meaningfully , supporting overall revenue growth.

---

### ✅ Recommendations

1. **Investigate the 4 customers with no recorded purchases.** Determine whether this is a data entry gap or genuinely inactive accounts, and consider a re-engagement outreach or data re-verification process for these records.
2. **Continue investing in multiple markets rather than concentrating on the top country.** Since combined spending from other countries ($1,447,800) significantly outweighs the top country alone ($71,500), revenue growth strategy should stay diversified rather than over-indexing on a single market.
3. **Standardize data entry at the source** (email format validation, dropdown country selection, consistent date input) to reduce the volume of cleaning required in future data cycles.

---

# 🚀 Outcome

- Cleaned 183 raw rows into a fully validated, analysis-ready dataset
- Identified and flagged 4 customers (2.3%) with missing purchase data for follow-up
- Recovered over $1.5M in total revenue previously scattered across inconsistent text, currency, and formatting issues
- Confirmed revenue is diversified across multiple countries rather than dependent on a single top market
- Delivered a reproducible SQL cleaning and analysis pipeline, fully documented step by step

---
