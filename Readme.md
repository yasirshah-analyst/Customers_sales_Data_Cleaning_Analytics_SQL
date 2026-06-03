# 📊 SQL Data Cleaning & Business Analysis Project

## 🧾 Project Overview
This project demonstrates an end-to-end SQL data cleaning and business analysis workflow using a messy dataset.  
The goal is to transform raw, inconsistent data into a clean analytical dataset and extract meaningful business insights such as customer behavior, revenue trends, and country-wise performance.

---

## 🗂️ Dataset
- **Source:** Kaggle  
- **Dataset Name:** Dirty Dataset for Data Cleaning Practice  
- **Columns:**
  - Customer_ID  
  - Customer_Name  
  - Email  
  - Country  
  - Last_Purchase_Date  
  - Total_Spent($)

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
select * from customers_sales_clean
where Customer_ID is null	
  and Customer_Name is null
  and Email is null
  and Country is null	
  and Last_Purchase_Date is null	
  and "Total_Spent($)" is null;

-- Delete blank rows
delete from customers_sales_clean
where Customer_ID is null	
  and Customer_Name is null
  and Email is null
  and Country is null	
  and Last_Purchase_Date is null	
  and "Total_Spent($)" is null;
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
update customers_sales_clean
set Customer_Name = trim(Customer_Name);

update customers_sales_clean
set Customer_Name = initcap(lower(Customer_Name));
```

---

## 🔹 Step 6: Clean Emails
We fix formatting issues and missing values.

```sql
update customers_sales_clean
set Email = lower(trim(Email));

update customers_sales_clean
set Email = replace(replace(Email,' ',''),'emailcom','email.com');

update customers_sales_clean
set Email = Email || '.com'
where Email not like '%.com';

update customers_sales_clean
set Email = 'No_Email_provided'
where Email is null;
```

---

## 🔹 Step 7: Standardize Country Names

```sql
update customers_sales_clean 
set Country = initcap(lower(trim(Country)));

update customers_sales_clean
set Country = 'USA'
where Country in ('Usa','U.S.A','U.S.A.');

update customers_sales_clean
set Country = 'UK'
where Country in ('Uk','U.K');

update customers_sales_clean
set Country = 'UAE'
where Country in ('Uae');

update customers_sales_clean
set Country = 'Unknown'
where Country is NULL;
```

---

## 🔹 Step 8: Standardize Dates

```sql
alter table customers_sales_clean
add column purchase_date date;

update customers_sales_clean
set purchase_date = to_date(Last_Purchase_Date,'MM/DD/YYYY');

update customers_sales_clean
set purchase_date = to_date(Last_Purchase_Date,'DD-MM-YYYY');

update customers_sales_clean
set purchase_date = to_date(Last_Purchase_Date,'DD-MON-YY');
```

---

## 🔹 Step 9: Clean Total Spent

```sql
update customers_sales_clean
set "Total_Spent($)" = replace(replace("Total_Spent($)",'$',''),',' ,'');

update customers_sales_clean 
set "Total_Spent($)" = ''
where upper(trim("Total_Spent($)")) in ('N/A','NULL','#VALUE');

alter table customers_sales_clean
alter column "Total_Spent($)" type numeric(12,2)
using NULLIF("Total_Spent($)",'')::numeric;
```

---

## 🔹 Step 10: Data Issue Flag

```sql
alter table customers_sales_clean
add column Data_Issue_Flag text;

update customers_sales_clean
set Data_Issue_Flag = case
	when purchase_date is NULL then 'Missing_Purchase_Date'
	else 'OK'
end;
```

---

## 🔹 Step 11: Data Quality Flag

```sql
alter table customers_sales_clean
add column Data_Quality_Flag text;

update customers_sales_clean
set Data_Quality_Flag = case
	when "Total_Spent($)" is NULL then 'Missing_Total_Spent'
	else 'OK'
end;
```

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
select 
round(
    100.0 * count(*) filter(where "Total_Spent($)" is null) / count(*),
2) as Percentage_Of_No_Purchase
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
select round(avg("Total_Spent($)"),2) as Average_Spend
from customers_sales_clean;
```

---

## Top Revenue Country
```sql
select Country,
       sum(coalesce("Total_Spent($)",0)) as revenue
from customers_sales_clean
group by Country
order by revenue desc
limit 1;
```

---

## Revenue by Country
```sql
select Country,
       sum(coalesce("Total_Spent($)",0)) as Total_Spending
from customers_sales_clean
group by Country
order by Total_Spending desc
limit 25;
```

---

# 🚀 Outcome
- Cleaned messy real-world dataset using SQL
- Handled missing values, duplicates, and inconsistencies
- Standardized text, dates, and numeric fields
- Generated meaningful business insights
- Built a strong Data Analyst portfolio project
```