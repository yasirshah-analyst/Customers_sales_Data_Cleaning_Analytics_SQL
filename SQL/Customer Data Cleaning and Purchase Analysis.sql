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

-- step 3: Removing Blank Rows

-- checking blank rows
select * from customers_sales_clean
where Customer_ID is null	
	  and Customer_Name	is null
	  and Email	is null
	  and Country is null	
	  and Last_Purchase_Date is null	
	  and "Total_Spent($)" is null;

--Deleting blank rows
delete from customers_sales_clean
where Customer_ID is null	
	  and Customer_Name	is null
	  and Email	is null
	  and Country is null	
	  and Last_Purchase_Date is null	
	  and "Total_Spent($)" is null;

-- step 4: Removing Duplicate Rows

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

--Step 5: Clean Customer Names

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

-- Step 6: Clean Email Addresses
 
-- Remove Spaces and lower the case
update customers_sales_clean
set Email = lower(trim(Email));

-- Fix "email com" and extra spaces inside email
update customers_sales_clean
set Email = replace(replace(Email,' ',''),'emailcom','email.com')
where Email like '% %' or Email like '%email com%';

-- Fix "@.com"
update customers_sales_clean
set Email = replace(Email,'@.com','@.emailcom')
where Email like '%@.com';

-- Fix Missing ".com"
update customers_sales_clean
set Email = Email || '.com'
where Email not like '%.com';

-- Handle Missing Emails
update customers_sales_clean
set Email = ''
where Email is null;

update customers_sales_clean
set Email = 'No_Email_provided'
where Email = '';

-- Replacing '@@' and '..' in Email with single
UPDATE customers_sales_clean
SET Email = REPLACE(REPLACE(Email, '@@', '@'), '..', '.');

-- Step 7: Standardize Country Names

-- proper case and Remove Extra Spaces
update customers_sales_clean 
set Country = initcap(lower(trim(Country)));

-- Correcting Country Abbreviations

update customers_sales_clean
set Country = 'USA'
where Country in('Usa','U.S.A','U.S.A.');

UPDATE customers_sales_clean
SET country = 'UK'
WHERE country IN ('Uk','U.K');

UPDATE customers_sales_clean
SET country = 'UAE'
WHERE country IN ('Uae');

UPDATE customers_sales_clean
SET country = REPLACE(
                REPLACE(
                  REPLACE(country, 'U.S.A', 'USA'),
                  'Usa', 'USA'),
                'U.K', 'UK');

-- replacing missing countries with "Unknown"
update customers_sales_clean
set Country = 'Unknown'
where Country is NULL;

Step 8: Standardize Dates

-- Create a new cleaned date column
alter table customers_sales_clean
add column purchase_date date;

-- Handle MM/DD/YYYY
update customers_sales_clean
set purchase_date = to_date(Last_Purchase_Date,'MM/DD/YYYY')
where Last_Purchase_Date ~ '^\d{1,2}/\d{1,2}/\d{4}$'

-- Handle DD-MM-YYYY
update customers_sales_clean
set purchase_date = to_date(Last_Purchase_Date,'DD-MM-YYYY')
where Last_Purchase_Date ~ '^\d{2}/\d{2}/\d{4}$'

-- Handle Text Dates
UPDATE customers_sales_clean
SET purchase_date =
TO_DATE(Last_Purchase_Date,'DD-MON-YY')
WHERE Last_Purchase_Date ~ '^\d{1,2}-[A-Za-z]{3}-\d{2}$';

-- Step 9: Clean Total Spent

-- Remove Dollar Signs and Commas
update customers_sales_clean
set "Total_Spent($)" = replace(replace("Total_Spent($)",'$',''),',','');

-- Convert Invalid Values
update customers_sales_clean 
set "Total_Spent($)" = ''
where upper(trim("Total_Spent($)"))
in ('N/A','NULL','#VALUE');

-- Convert Total Spent to Numeric
alter table customers_sales_clean
alter column "Total_Spent($)" type numeric(12,2)
using NULLIF("Total_Spent($)",'') :: numeric;

-- Step 10: Create Data Issue Flag

alter table customers_sales_clean
add column Data_Issue_Flag text;

update customers_sales_clean
set Data_Issue_Flag = case
						when purchase_date is NULL then 'Missing_Purchase_Date'
						else 'OK'
					  end;
					  
-- Step 11: Create Data Quality Flag

alter table customers_sales_clean
add column Data_Quality_Flag text;

update customers_sales_clean
set Data_Quality_Flag = case
							when "Total_Spent($)" is Null then 'Missing_Total_Spent'
							else 'OK'
						end;


select * from customers_sales_clean
order by Customer_Id;

-- Analysis
-- the dataset was analyzed to answer the following business questions

-- What is the total number of unique customers?
select count(*) as Total_Customers
from customers_sales_clean;

-- How many customers have made zero purchases ?
select count(*) as zero_purchases
from customers_sales_clean 
where "Total_Spent($)" is null;

-- What percentage of customers made no purchase?
select 
round(100.0*count(*) filter(where "Total_Spent($)" is null)/count(*),2) 
as Percentage_Of_No_Purchase
from customers_sales_clean;

-- What is the overall total spending?
select sum("Total_Spent($)") as "Total_Spending($)"
from customers_sales_clean;

-- What is the average spend per customer?
select 
round(avg("Total_Spent($)") ,2) as "Average_Spend_Per_Customer($)"
from customers_sales_clean;

-- Which country generate the highest revenue?
select Country,sum(coalesce("Total_Spent($)",0)) as "revenue"
from customers_sales_clean
group by Country
order by revenue desc
limit 1;

-- How is total spending distributed by country?
select Country,sum(coalesce("Total_Spent($)",0)) as "Total_Spending($)"
from customers_sales_clean
group by Country
order by "Total_Spending($)" desc
Limit 25;

-- checking missing values column by column
select * from customers_sales_clean
where Customer_Id is null or trim(Customer_Id) = ''
	or Customer_Name is null or trim(Customer_Name) = ''
	or Email is null or trim(Email) = ''
	or Country is null or trim(Country) = ''
	or Last_Purchase_Date is null or trim(Last_Purchase_Date) = ''
	or "Total_Spent($)" is null or trim("Total_Spent($)") = '';
