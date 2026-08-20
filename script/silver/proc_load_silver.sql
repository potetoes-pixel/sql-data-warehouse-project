-- =============================================================================
-- 🚀 ==========================================================================
-- 🏢        DATA WAREHOUSE ETL PIPELINE: SILVER LAYER INGESTION
-- 🎯        STORED PROCEDURE: silver.load_silver
-- 🛠️        TRANSFORMATION, NORMALIZATION & DATA QUALITY FRAMEWORK
-- ========================================================================== 🚀
-- =============================================================================

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME
        BEGIN TRY

            -- =============================================================================
            -- 🏁 ETL BATCH INITIALIZATION & EXECUTION START
            -- =============================================================================
            PRINT '=============================================================================';
            PRINT 'Starting Batch Load: Silver Layer';
            PRINT '=============================================================================';

            SET @batch_start_time = GETDATE();


            -- =============================================================================
            -- 👥 SECTION 1: CRM DOMAIN DATA PIPELINES (Customer, Products, Sales)
            -- =============================================================================
            PRINT '*****************************************************************************';
            PRINT '1. Loading CRM Domain Tables';
            PRINT '*****************************************************************************';


            -- -----------------------------------------------------------------------------
            -- 👤 1.1 TABLE: silver.crm_cust_info (Customer Dimension)
            -- -----------------------------------------------------------------------------
            SET @start_time = GETDATE();

            PRINT '>> Truncating Table: silver.crm_cust_info';
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
        
            SET @end_time = GETDATE();
            PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
            PRINT '>> -----------------------------------------------------------------------------';



            -- -----------------------------------------------------------------------------
            -- 🏷️ 1.2 TABLE: silver.crm_prd_info (Product Dimension)
            -- -----------------------------------------------------------------------------
            SET @start_time = GETDATE();

            PRINT '>> Truncating Table: silver.crm_prd_info';
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

            SET @end_time = GETDATE();
            PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
            PRINT '>> -----------------------------------------------------------------------------';



            -- -----------------------------------------------------------------------------
            -- 🧾 1.3 TABLE: silver.crm_sales_details (Sales Fact / Transactions)
            -- -----------------------------------------------------------------------------
            SET @start_time = GETDATE();

            PRINT '>> Truncating Table: silver.crm_sales_details';
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

            SET @end_time = GETDATE();
            PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
            PRINT '>> -----------------------------------------------------------------------------';



            -- =============================================================================
            -- 🌐 SECTION 2: ERP DOMAIN DATA PIPELINES (Demographics, Location, Category)
            -- =============================================================================
            PRINT '*****************************************************************************';
            PRINT '2. Loading ERP Domain Tables';
            PRINT '*****************************************************************************';


            -- -----------------------------------------------------------------------------
            -- 🎂 2.1 TABLE: silver.erp_cust_az12 (ERP Demographics)
            -- -----------------------------------------------------------------------------
            SET @start_time = GETDATE();

            PRINT '>> Truncating Table: silver.erp_cust_az12';
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

            SET @end_time = GETDATE();
            PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
            PRINT '>> -----------------------------------------------------------------------------';



            -- -----------------------------------------------------------------------------
            -- 🌍 2.2 TABLE: silver.erp_loc_a101 (ERP Geography & Locations)
            -- -----------------------------------------------------------------------------
            SET @start_time = GETDATE();

            PRINT '>> Truncating Table: silver.erp_loc_a101';
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

            SET @end_time = GETDATE();
            PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
            PRINT '>> -----------------------------------------------------------------------------';



            -- -----------------------------------------------------------------------------
            -- 📑 2.3 TABLE: silver.erp_px_cat_g1v2 (ERP Product Categories)
            -- -----------------------------------------------------------------------------
            SET @start_time = GETDATE();

            PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
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

            SET @end_time = GETDATE();
            PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
            PRINT '>> -----------------------------------------------------------------------------';


            -- =============================================================================
            -- 🏁 ETL BATCH COMPLETION SUMMARY
            -- =============================================================================
            SET @batch_end_time = GETDATE();
            PRINT '=============================================================================';
            PRINT 'Silver Layer Load Completed Successfully!';
            PRINT 'Total Batch Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
            PRINT '=============================================================================';

        END TRY
        BEGIN CATCH
            -- =============================================================================
            -- 🚨 ERROR HANDLING & DIAGNOSTICS (CATCH BLOCK)
            -- =============================================================================
            PRINT '=============================================================================';
            PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';
            PRINT 'Error Message   : ' + ERROR_MESSAGE();
            PRINT 'Error Number    : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
            PRINT 'Error State     : ' + CAST(ERROR_STATE() AS NVARCHAR);
            PRINT 'Error Line      : ' + CAST(ERROR_LINE() AS NVARCHAR);
            PRINT 'Error Procedure : ' + ISNULL(ERROR_PROCEDURE(), 'silver.load_silver');
            PRINT '=============================================================================';
        END CATCH

END;
GO

-- =============================================================================
-- 🚀 PROCEDURE EXECUTION & RUNTIME TRIGGER
-- =============================================================================
EXEC silver.load_silver;

-- 💡 Note: Track ETL Duration to identify bottlenecks, optimize performance, monitor trends, and detect anomalies.
