-- Step 1: Create Raw Table
	
-- Since the data contains dirty values, import everything as TEXT initially

create table customers_sales_raw(
	Customer_ID text,
	Customer_Name text,
	Email text,
	Country text,
	Last_Purchase_Date text,
	"Total_Spent($)" text
);

select * from customers_sales_raw;

-- Step 2: Create a Working Copy

create table customers_sales_clean as
select * from customers_sales_raw;

-- checking blank rows
select * from customers_sales_clean
where Customer_ID = 'NULL';

--Deleting blank rows
delete from customers_sales_clean
where Customer_ID = 'NULL';	

-- checking duplicate rows
select * from (
              select *,
              row_number() over(partition by Customer_Id) as rn
              from customers_sales_clean
			  )
where rn > 1;

-- deleting duplicate rows
DELETE FROM customers_sales_clean
WHERE ctid IN (
    SELECT ctid
    FROM (
        SELECT ctid,
               ROW_NUMBER() OVER(
                   PARTITION BY customer_id
               ) AS rn
        FROM customers_sales_clean
    ) 
    WHERE rn > 1
);

-- Checking Leading & Trailing Spaces in Customer_Name

select Customer_Name 
from customers_sales_clean
where Customer_Name <> trim(Customer_Name);

-- Remove Leading & Trailing Spaces in
update customers_sales_clean
set Customer_Name = trim(Customer_Name);

-- Standardize Case
update customers_sales_clean
set Customer_Name = Initcap(lower(Customer_Name));

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

-- STEP 4b: Fix trailing dots left behind from space removal (e.g., 'email.' -> 'email.com')
UPDATE customers_sales_clean
SET email = email || 'com'
WHERE email LIKE '%@email.';

-- Step 7: Standardize Country Names

-- 1. Wipe extra spaces and lower everything to make matching simple
UPDATE customers_sales_clean 
SET country = LOWER(TRIM(country));

-- 2. Standardize Standalone Abbreviations (Forces them to uppercase)
UPDATE customers_sales_clean SET country = 'USA' WHERE country IN ('usa', 'u.s.a', 'u.s.a.');
UPDATE customers_sales_clean SET country = 'UK'  WHERE country IN ('uk', 'u.k', 'u.k.');
UPDATE customers_sales_clean SET country = 'UAE' WHERE country IN ('uae');

-- 3. Handle Missing/String NULL Countries
UPDATE customers_sales_clean
SET country = 'Unknown'
WHERE country IS NULL OR country = 'null' OR country = '';

-- 4. Capitalize regular countries 
-- (CRITICAL FIX: Changed to uppercase 'USA','UK','UAE' to match Step 2!)
UPDATE customers_sales_clean
SET country = INITCAP(country)
WHERE country NOT IN ('USA', 'UK', 'UAE', 'Unknown')
  AND country NOT LIKE '%/%';

-- 5. Capitalize full country combinations (e.g., 'china/japan' -> 'China/Japan')
UPDATE customers_sales_clean
SET country = INITCAP(country)
WHERE country LIKE '%/%';

-- 6. Clean up abbreviation fragments globally (Forces 'Usa' -> 'USA' everywhere)
-- (CRITICAL FIX: Removed WHERE country LIKE '%/%' so it fixes standalone rows too!)
UPDATE customers_sales_clean
SET country = REGEXP_REPLACE(
                REGEXP_REPLACE(
                  REGEXP_REPLACE(country, 'usa', 'USA', 'i'), 
                'uk', 'UK', 'i'),
              'uae', 'UAE', 'i');

-- 7. Specific literal cleanup for dotted slashes (Fixes 'U.S.A/U.K' -> 'USA/UK')
UPDATE customers_sales_clean
SET country = REPLACE(REPLACE(country, 'U.S.A', 'USA'), 'U.K', 'UK')
WHERE country LIKE '%/%';

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



-- Step 9: Clean Total Spent

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



select * from customers_sales_clean
order by Customer_Id;

UPDATE customers_sales_clean
SET Data_Quality_Flag = CASE
                            WHEN Last_Purchase_Date IS NULL AND "Total_Spent($)" IS NULL THEN 'Missing Date & Spent'
                            WHEN Last_Purchase_Date IS NULL THEN 'Missing_Purchase_Date'
                            WHEN "Total_Spent($)" IS NULL THEN 'Missing_Total_Spent'
                            ELSE 'OK'
                        END;
