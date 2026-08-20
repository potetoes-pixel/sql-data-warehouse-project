-- =============================================================================
-- ✨ DATA TRANSFORMATION & DATA QUALITY PIPELINE: ERP TABLES (erp_cust_az12) 📊
-- =============================================================================


-- =============================================================================
-- 🔍 PHASE 1: BRONZE QUALITY CHECKS (Exploration & Anomaly Detection)
-- =============================================================================

-- 1️⃣ 🔑 CID Transformation Check & Referential Integrity (ERP ➔ CRM Match)
SELECT 
    cid,
    CASE 
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
        ELSE cid 
    END AS cleaned_cid
FROM bronze.erp_cust_az12
WHERE 
    CASE 
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
        ELSE cid 
    END NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- 2️⃣ 🎂 Birthday Anomaly Check (Future Dates or Unrealistic Past Dates < 1924)
SELECT 
    cid, 
    bdate, 
    gen
FROM bronze.erp_cust_az12
WHERE bdate <= '1924-01-01' OR bdate > GETDATE();

-- 3️⃣ 🚻 Gender Normalization & Whitespace Check
SELECT DISTINCT 
    gen AS original_gen,
    CASE 
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
        ELSE 'n/a'
    END AS normalized_gen
FROM bronze.erp_cust_az12;



-- =============================================================================
-- 📜 BUSINESS RULES & DATA TRANSFORMATION SPECS
-- =============================================================================
-- 📌 RULE 1 (Customer Key Alignment) : Strip 'NAS' prefix from CID (chars 4+) to align with CRM keys.
-- 📌 RULE 2 (Future Date Defense)    : Replace any future birthdates (bdate > GETDATE()) with NULL.
-- 📌 RULE 3 (Gender Normalization)   : Standardize variants ('M', 'Male' ➔ 'Male', 'F', 'Female' ➔ 'Female', others ➔ 'n/a').
-- =============================================================================



-- =============================================================================
-- ⚙️ PHASE 2: SILVER DATA TRANSFORMATION & INGESTION
-- =============================================================================
PRINT '>> Truncating TAble: silver.erp_cust_az12';
TRUNCATE TABLE silver.erp_cust_az12;
PRINT '>> Inserting Data Into: silver.erp_cust_az12';
INSERT INTO silver.erp_cust_az12 (
    CID,
    BDATE,
    GEN
)
SELECT
    CASE 
        WHEN CID LIKE 'NAS%' THEN SUBSTRING(CID, 4, LEN(CID))
        ELSE CID
    END AS CID,                                         -- 🔑 Cleaned customer key (prefix removed)
    CASE 
        WHEN BDATE > GETDATE() THEN NULL 
        ELSE BDATE 
    END AS BDATE,                                       -- 🛡️ Set invalid future birthdates to NULL
    CASE 
        WHEN UPPER(TRIM(GEN)) IN ('F', 'Female') THEN 'Female'
        WHEN UPPER(TRIM(GEN)) IN ('M', 'Male')   THEN 'Male'
        ELSE 'n/a'
    END AS GEN                                          -- 🚻 Normalized gender representation
FROM bronze.erp_cust_az12;



-- =============================================================================
-- ✅ PHASE 3: POST-LOAD VALIDATION CHECKS (Silver Layer QA)
-- =============================================================================

-- 1️⃣ 🛡️ Ensure No 'NAS' Prefixes Remain in Silver CID
SELECT 
    cid 
FROM silver.erp_cust_az12 
WHERE cid LIKE 'NAS%';

-- 2️⃣ 📅 Verify No Future Birthdates Exist in Silver
SELECT 
    cid, 
    bdate 
FROM silver.erp_cust_az12 
WHERE bdate > GETDATE();

-- 3️⃣ 🚻 Verify Gender Column Contains ONLY Standardized Values ('Female', 'Male', 'n/a')
SELECT DISTINCT 
    gen 
FROM silver.erp_cust_az12;

-- 4️⃣ 🔎 Final Full Table Inspection
SELECT * FROM silver.erp_cust_az12;




-- =============================================================================
-- ✨ DATA TRANSFORMATION & DATA QUALITY PIPELINE: ERP TABLES (erp_loc_a101) 📊
-- =============================================================================


-- =============================================================================
-- 🔍 PHASE 1: BRONZE QUALITY CHECKS (Exploration & Anomaly Detection)
-- =============================================================================

-- 1️⃣ 🔑 CID Standardization & Referential Integrity (ERP ➔ CRM Match)
SELECT 
    cid,
    REPLACE(cid, '-', '') AS cleaned_cid,
    cntry
FROM bronze.erp_loc_a101
WHERE REPLACE(cid, '-', '') NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- 2️⃣ 🌍 Country Standardization & Consistency Preview
SELECT DISTINCT
    cntry AS original_cntry,
    CASE 
        WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
        WHEN UPPER(TRIM(cntry)) = 'DE'           THEN 'Germany'
        WHEN cntry IS NULL OR TRIM(cntry) = ''   THEN 'n/a'
        ELSE TRIM(cntry)
    END AS normalized_cntry
FROM bronze.erp_loc_a101
ORDER BY original_cntry;



-- =============================================================================
-- 📜 BUSINESS RULES & DATA TRANSFORMATION SPECS
-- =============================================================================
-- 📌 RULE 1 (Customer Key Formatting) : Strip hyphens ('-') from CID to match CRM customer keys.
-- 📌 RULE 2 (Country Standardization)  : Map country abbreviations to full names ('US'/'USA' ➔ 'United States', 'DE' ➔ 'Germany').
-- 📌 RULE 3 (Missing Country Defense)  : Replace NULL, blank, or whitespace-only country entries with 'n/a'.
-- 📌 RULE 4 (Whitespace Sanitization)  : Strip leading/trailing spaces from country names using TRIM().
-- =============================================================================



-- =============================================================================
-- ⚙️ PHASE 2: SILVER DATA TRANSFORMATION & INGESTION
-- =============================================================================
PRINT '>> Truncating TAble: silver.erp_loc_a101';
TRUNCATE TABLE silver.erp_loc_a101;
PRINT '>> Inserting Data Into: silver.erp_loc_a101';
INSERT INTO silver.erp_loc_a101 (
    CID,
    CNTRY
)
SELECT 
    REPLACE(CID, '-', '') AS CID,                       -- 🔑 Cleaned customer key (hyphens removed)
    CASE 
        WHEN UPPER(TRIM(CNTRY)) IN ('US', 'USA') THEN 'United States'
        WHEN UPPER(TRIM(CNTRY)) = 'DE'           THEN 'Germany'
        WHEN CNTRY IS NULL OR TRIM(CNTRY) = ''   THEN 'n/a'
        ELSE TRIM(CNTRY)
    END AS CNTRY                                        -- 🌍 Standardized & sanitized country name
FROM bronze.erp_loc_a101;



-- =============================================================================
-- ✅ PHASE 3: POST-LOAD VALIDATION CHECKS (Silver Layer QA)
-- =============================================================================

-- 1️⃣ 🛡️ Verify No Hyphens Remain in Silver CID
SELECT 
    cid 
FROM silver.erp_loc_a101 
WHERE cid LIKE '%-%';

-- 2️⃣ 🌍 Verify Country Standardization (Ensure No Codes, Raw Abbreviations, or Blank Values Remain)
SELECT DISTINCT 
    cntry 
FROM silver.erp_loc_a101
ORDER BY cntry;

-- 3️⃣ ✂️ Check for Remaining Leading/Trailing Whitespace in Silver Country
SELECT 
    cntry 
FROM silver.erp_loc_a101 
WHERE cntry != TRIM(cntry);

-- 4️⃣ 🔎 Final Full Table Inspection
SELECT * FROM silver.erp_loc_a101;




-- =============================================================================
-- ✨ DATA TRANSFORMATION & DATA QUALITY PIPELINE: ERP TABLES (erp_loc_a101) 📊
-- =============================================================================


-- =============================================================================
-- 🔍 PHASE 1: BRONZE QUALITY CHECKS (Exploration & Anomaly Detection)
-- =============================================================================


-- 1️⃣ 🔑 Duplicate Primary Key Check (ID Column)
SELECT 
    id,
    COUNT(*) AS duplicate_count
FROM bronze.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1;

-- 2️⃣ ✂️ Whitespace & Integrity Checks (Category & Subcategory)
SELECT 
    id,
    cat,
    subcat
FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat) OR subcat != TRIM(subcat);

-- 3️⃣ 🗂️ Distinct Values Inspection (Category, Subcategory, Maintenance)
SELECT DISTINCT cat FROM bronze.erp_px_cat_g1v2 ORDER BY cat;
SELECT DISTINCT subcat FROM bronze.erp_px_cat_g1v2 ORDER BY subcat;
SELECT DISTINCT maintenance FROM bronze.erp_px_cat_g1v2 ORDER BY maintenance;



-- =============================================================================
-- 📜 BUSINESS RULES & DATA TRANSFORMATION SPECS
-- =============================================================================
-- 📌 RULE 1 (Primary Key Integrity) : ID column contains unique category identifiers; no deduplication required.
-- 📌 RULE 2 (Whitespace Cleanliness): CAT and SUBCAT strings are clean of leading/trailing spaces.
-- 📌 RULE 3 (Standard Pass-Through) : Data in Bronze is already clean; direct ingestion into Silver layer.
-- =============================================================================



-- =============================================================================
-- ⚙️ PHASE 2: SILVER DATA TRANSFORMATION & INGESTION
-- =============================================================================

PRINT '>> Truncating TAble: silver.erp_px_cat_g1v2';
TRUNCATE TABLE silver.erp_px_cat_g1v2;
PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
INSERT INTO silver.erp_px_cat_g1v2 (
    ID,
    CAT,
    SUBCAT,
    MAINTENANCE
)
SELECT 
    ID,                                                 -- 🔑 Category ID (Joins with silver.crm_prd_info.cat_id)
    CAT,                                                -- 🏷️ Product Category Name
    SUBCAT,                                             -- 📑 Product Subcategory Name
    MAINTENANCE                                         -- 🔧 Maintenance Flag / Indicator
FROM bronze.erp_px_cat_g1v2;
