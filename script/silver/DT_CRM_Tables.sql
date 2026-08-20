/*
===============================================================================
✨ DATA TRANSFORMATION & DATA QUALITY PIPELINE : CRM TABLES
===============================================================================
🎯 BUSINESS & DATA WAREHOUSE RULES:
   1. 🏷️ Standardization: Store clear, meaningful, and fully expanded values 
                          instead of cryptic codes/abbreviations.
   2. 🛡️ Default Handling: Populate missing, null, or invalid values with 'n/a'.
===============================================================================
*/


-- =============================================================================
-- 🔍 STEP 1: DATA QUALITY CHECK - IDENTIFY PRIMARY KEY DUPLICATES & NULLS
-- =============================================================================
-- 📌 Objective: Ensure 'cst_id' uniquely identifies each record and has no NULLs.
-- ⚠️ Quality Rule: A Primary Key must be unique (COUNT = 1) and NOT NULL.

SELECT
    cst_id,
    COUNT(*) AS duplicate_count
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 
    OR cst_id IS NULL;


-- -----------------------------------------------------------------------------
-- 🧹 Deduplication Strategy Demonstration
-- 💡 Tip: When duplicate IDs exist, retain the latest record based on 'cst_create_date'.
-- -----------------------------------------------------------------------------
SELECT * 
FROM (
    SELECT 
        *,
        ROW_NUMBER() OVER(
            PARTITION BY cst_id 
            ORDER BY cst_create_date DESC
        ) AS flag_last
    FROM bronze.crm_cust_info
) AS t
WHERE flag_last = 1;



-- =============================================================================
-- 🔍 STEP 2: DATA QUALITY CHECK - DETECT UNWANTED LEADING / TRAILING SPACES
-- =============================================================================
-- 📌 Logic: If Original != Trimmed, hidden whitespace exists.
-- 🎯 Target: Zero records returned (Expectation: Clean strings).

-- ⚠️ First Name Check (Dirty data found: Contains extra spaces)
SELECT 
    cst_firstname
FROM bronze.crm_cust_info 
WHERE cst_firstname != TRIM(cst_firstname);

-- ⚠️ Last Name Check (Dirty data found: Contains extra spaces)
SELECT 
    cst_lastname
FROM bronze.crm_cust_info 
WHERE cst_lastname != TRIM(cst_lastname);

-- ✅ Marital Status Check (Clean data: No extra spaces found)
SELECT 
    cst_marital_status
FROM bronze.crm_cust_info 
WHERE cst_marital_status != TRIM(cst_marital_status);

-- ✅ Gender Check (Clean data: No extra spaces found)
SELECT 
    cst_gndr
FROM bronze.crm_cust_info 
WHERE cst_gndr != TRIM(cst_gndr);



-- =============================================================================
-- 🔍 STEP 3: DATA QUALITY CHECK - CARDINALITY & VALUE CONSISTENCY
-- =============================================================================
-- 📌 Objective: Review distinct domain values to map normalization rules.

SELECT DISTINCT 
    cst_gndr 
FROM bronze.crm_cust_info;



-- =============================================================================
-- 🚀 FINAL STEP: CLEANSE, TRANSFORM & LOAD INTO SILVER LAYER
-- =============================================================================
-- 📋 Transformation Pipeline Actions:
--    1. ✂️ Trimming: Strips unwanted whitespace from text fields.
--    2. 🏷️ Normalization: Expands abbreviations (e.g., 'M' ➔ 'Married', 'F' ➔ 'Female').
--    3. 🛡️ Imputation: Replaces NULL/unmatched values with 'n/a'.
--    4. 🧹 Deduplication: Partitions by 'cst_id' and keeps the newest snapshot.
-- =============================================================================
PRINT '>> Truncating TAble: silver.crm_cust_info';
TRUNCATE TABLE silver.crm_cust_info;
PRINT '>> Inserting Data Into: silver.crm_cust_info';
INSERT INTO silver.crm_cust_info (
    cst_id,
    cst_key, 
    cst_firstname,
    cst_lastname, 
    cst_marital_status, 
    cst_gndr, 
    cst_create_date 
)
SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname, -- ✂️ Remove unwanted whitespace
    TRIM(cst_lastname)  AS cst_lastname,  -- ✂️ Remove unwanted whitespace
    
    -- 🏷️ Standardize Marital Status & 🛡️ Handle Missing Values
    CASE 
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married' 
        ELSE 'n/a'
    END AS cst_marital_status,
    
    -- 🏷️ Standardize Gender & 🛡️ Handle Missing Values
    CASE 
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female' 
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'n/a'
    END AS cst_gndr,
    
    cst_create_date
FROM (
    SELECT 
        *,
        -- 🧹 Rank records to flag and isolate the newest customer record
        ROW_NUMBER() OVER(
            PARTITION BY cst_id 
            ORDER BY cst_create_date DESC
        ) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL              -- 🛡️ Filter out invalid NULL primary keys
) AS t
WHERE flag_last = 1;                      -- 🎯 Keep only the most recent unique record



-- =============================================================================
-- 🧹 2. CRM PRODUCT INFO: DATA CLEANING & ETL PIPELINE 📊
-- =============================================================================


-- =============================================================================
-- 🔍 PHASE 1: BRONZE QUALITY CHECKS (Exploration & Anomaly Detection)
-- =============================================================================

-- 1️⃣ 🔑 Check for Duplicates in Primary Key
SELECT 
    prd_id, 
    COUNT(*) AS duplicate_count
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1;

-- 2️⃣ ✂️ Check for Unwanted Leading/Trailing Spaces in Product Name
SELECT 
    prd_nm 
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- 3️⃣ 🔠 Check Distinct Values for Product Line (Normalization Check)
SELECT DISTINCT 
    prd_line
FROM bronze.crm_prd_info;

-- 4️⃣ 💰 Check for NULLs, Zero, or Negative Costs in Source
SELECT 
    prd_id,
    prd_cost 
FROM bronze.crm_prd_info 
WHERE prd_cost <= 0 OR prd_cost IS NULL;

-- 5️⃣ 📅 Check for Overlapping Dates / Invalid Sequences in Source
SELECT 
    prd_id,
    prd_key,
    prd_nm,
    prd_start_dt,
    LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS calculated_end_dt
FROM bronze.crm_prd_info
WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509');



-- =============================================================================
-- ⚙️ PHASE 2: SILVER DATA TRANSFORMATION & INGESTION
-- =============================================================================

-- 🧼 Optional: Reset target table before reload

PRINT '>> Truncating TAble: silver.crm_prd_info';
TRUNCATE TABLE silver.crm_prd_info;
PRINT '>> Inserting Data Into: silver.crm_prd_info';
INSERT INTO silver.crm_prd_info (
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
)
SELECT
    prd_id,
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,     -- 🏷️ Extract Category ID (Joins with erp_px_cat_g1v2)
    SUBSTRING(prd_key, 7, LEN(prd_key))         AS prd_key,    -- 🔑 Extract Product Key (Joins with crm_sales_details)
    TRIM(prd_nm)                                AS prd_nm,     -- ✂️ Trim any stray whitespace
    ISNULL(prd_cost, 0)                         AS prd_cost,   -- 🛡️ Handle NULL costs (Default to 0)
    CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a' 
    END                                         AS prd_line,   -- 🗂️ Normalize Product Line codes
    CAST(prd_start_dt AS DATE)                  AS prd_start_dt,
    CAST(
        LEAD(prd_start_dt) OVER (
            PARTITION BY SUBSTRING(prd_key, 7, LEN(prd_key)) 
            ORDER BY prd_start_dt
        ) - 1 
        AS DATE
    )                                           AS prd_end_dt  -- 📈 Enrich End Date using chronological sequence
FROM bronze.crm_prd_info;



-- =============================================================================
-- ✅ PHASE 3: POST-LOAD VALIDATION CHECKS (Silver Layer QA)
-- =============================================================================

-- 1️⃣ 🛡️ Verify No Unhandled NULL Costs in Silver Layer
SELECT 
    prd_id,
    prd_cost 
FROM silver.crm_prd_info 
WHERE prd_cost IS NULL;

-- 2️⃣ 📅 Check for Invalid Date Orders (End Date earlier than Start Date)
SELECT 
    * 
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- 3️⃣ 🔬 Sample Specific Product History Verification
SELECT 
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_start_dt,
    prd_end_dt
FROM silver.crm_prd_info
WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509', 'HL-U509-R', 'HL-U509');

-- 4️⃣ 🔎 Final Full Table Inspection
SELECT * FROM silver.crm_prd_info;




-- =============================================================================
-- 🧹 CRM SALES DETAILS: DATA CLEANING & ETL PIPELINE 📊
-- =============================================================================


-- =============================================================================
-- 🔍 PHASE 1: BRONZE QUALITY CHECKS (Exploration & Anomaly Detection)
-- =============================================================================

-- 1️⃣ ✂️ Check for Unwanted Leading/Trailing Spaces in Order Number
SELECT 
    sls_ord_num 
FROM bronze.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num);

-- 2️⃣ 🔗 Referential Integrity Checks (Orphaned Records)
-- Check for Product Keys missing from Dim Product
SELECT sls_ord_num, sls_prd_key, sls_cust_id 
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);

-- Check for Customer IDs missing from Dim Customer
SELECT sls_ord_num, sls_prd_key, sls_cust_id 
FROM bronze.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);

-- 3️⃣ 📅 Consolidated Date Quality & Range Validation Check
-- (Checks Zeros, Invalid String Lengths, Out-of-Range Dates, and Illogical Sequences)
SELECT 
    sls_ord_num,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt
FROM bronze.crm_sales_details
WHERE 
    -- Invalid Order Dates (Zeros, Bad Length, Out-of-Bound Range)
    (sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 OR sls_order_dt > 20250101 OR sls_order_dt < 19000101)
    -- Invalid Ship Dates
    OR (sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 OR sls_ship_dt > 20250101 OR sls_ship_dt < 19000101)
    -- Invalid Due Dates
    OR (sls_due_dt <= 0 OR LEN(sls_due_dt) != 8 OR sls_due_dt > 20250101 OR sls_due_dt < 19000101)
    -- Illogical Date Sequences
    OR (sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt OR sls_ship_dt >= sls_due_dt);

-- 4️⃣ 💰 Check Financial Discrepancies (Sales != Qty * Price OR Negatives / Zeros / NULLs)
SELECT 
    sls_sales AS old_sls_sales,
    sls_quantity,
    sls_price AS old_sls_price,
    CASE
        WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
        THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END AS recalculated_sls_sales,
    CASE 
        WHEN sls_price IS NULL OR sls_price <= 0 
        THEN sls_sales / NULLIF(sls_quantity, 0)
        ELSE sls_price
    END AS recalculated_sls_price
FROM bronze.crm_sales_details
WHERE 
    sls_sales != sls_quantity * sls_price 
    OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
    OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;



-- =============================================================================
-- 📜 BUSINESS RULES & DATA TRANSFORMATION SPECS
-- =============================================================================
-- 📌 RULE 1 (Date Standardization): Convert INT (YYYYMMDD) to DATE; replace 0 or bad lengths with NULL.
-- 📌 RULE 2 (Sales Correction)     : If Sales is NULL, <= 0, or != (Qty * |Price|), derive as Qty * |Price|.
-- 📌 RULE 3 (Price Correction)     : If Price is NULL or <= 0, calculate as Sales / Qty.
-- 📌 RULE 4 (Negative Handling)    : If Price is negative, convert it to positive using ABS().
-- 📌 RULE 5 (Zero-Division Guard)  : Prevent division by zero using NULLIF(sls_quantity, 0).
-- =============================================================================



-- =============================================================================
-- ⚙️ PHASE 2: SILVER DATA TRANSFORMATION & INGESTION
-- =============================================================================
PRINT '>> Truncating TAble: silver.crm_sales_details';
TRUNCATE TABLE silver.crm_sales_details;
PRINT '>> Inserting Data Into: silver.crm_sales_details';
INSERT INTO silver.crm_sales_details (
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
)
SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    CASE 
        WHEN sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 THEN NULL -- 🛡️ Handling invalid data 
        ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)            -- 📅 Data type casting 
    END AS sls_order_dt,
    CASE 
        WHEN sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 THEN NULL 
        ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
    END AS sls_ship_dt,
    CASE 
        WHEN sls_due_dt <= 0 OR LEN(sls_due_dt) != 8 THEN NULL 
        ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
    END AS sls_due_dt,
    CASE
        WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) -- 🛡️ Handling missing/incorrect sales
        THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END AS sls_sales,                                              -- 💵 Recalculate sales if needed
    sls_quantity,
    CASE 
        WHEN sls_price IS NULL OR sls_price <= 0 
        THEN sls_sales / NULLIF(sls_quantity, 0)
        ELSE sls_price
    END AS sls_price                                               -- 🏷️ Derive price if original value is invalid
FROM bronze.crm_sales_details;



-- =============================================================================
-- ✅ PHASE 3: POST-LOAD VALIDATION CHECKS (Silver Layer QA)
-- =============================================================================

-- 🛡️ Business Rule QA: Sales must equal (Quantity * Price) with no NULLs, zeros, or negatives
SELECT 
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE 
    sls_sales != sls_quantity * sls_price 
    OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
    OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- 🔎 Final Verification Check
SELECT * FROM silver.crm_sales_details;
