/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates the raw staging tables for the 'Bronze' layer of the 
    data warehouse. It drops existing tables if they already exist to ensure 
    a clean re-runnable deployment.

Source Systems:
    1. CRM (Customer Relationship Management)
    2. ERP (Enterprise Resource Planning)
===============================================================================
*/

-- =============================================================================
-- 1. CRM TABLES (Customer, Product, Sales)
-- =============================================================================

-------------------------------------------------------------------------------
-- Table: bronze.crm_cust_info
-- Description: Stores customer demographic and profile information from CRM.
-------------------------------------------------------------------------------
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL 
    DROP TABLE bronze.crm_cust_info;
GO

CREATE TABLE bronze.crm_cust_info (
    cst_id               INT,            -- Unique identifier for the customer
    cst_key              NVARCHAR(50),   -- Business/Alternate key for the customer
    cst_firstname        NVARCHAR(50),   -- Customer's first name
    cst_lastname         NVARCHAR(50),   -- Customer's last name
    cst_marital_status   NVARCHAR(50),   -- Marital status (e.g., Single, Married)
    cst_gndr             NVARCHAR(50),   -- Gender
    cst_create_date      DATE            -- Record/Account creation date
);
GO


-------------------------------------------------------------------------------
-- Table: bronze.crm_prd_info
-- Description: Stores product catalog, pricing, and lifecycle dates from CRM.
-------------------------------------------------------------------------------
IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL 
    DROP TABLE bronze.crm_prd_info;
GO

CREATE TABLE bronze.crm_prd_info (
    prd_id          INT,            -- Unique identifier for the product
    prd_key         NVARCHAR(50),   -- Business/SKU key used across systems
    prd_nm          NVARCHAR(50),   -- Product name/description
    prd_cost        INT,            -- Base manufacturing or purchase cost
    prd_line        NVARCHAR(50),   -- Product line or category code
    prd_start_dt    DATETIME,       -- Product availability start date & time
    prd_end_dt      DATETIME        -- Product sunset/discontinuation date & time
);
GO


-------------------------------------------------------------------------------
-- Table: bronze.crm_sales_details
-- Description: Stores transactional sales order line items from CRM.
-------------------------------------------------------------------------------
IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL 
    DROP TABLE bronze.crm_sales_details;
GO

CREATE TABLE bronze.crm_sales_details (
    sls_ord_num     NVARCHAR(50),   -- Sales order number
    sls_prd_key     NVARCHAR(50),   -- Foreign reference to product key
    sls_cust_id     INT,            -- Foreign reference to customer ID
    sls_order_dt    INT,            -- Order date in integer format (e.g., YYYYMMDD)
    sls_ship_dt     INT,            -- Shipping date in integer format (e.g., YYYYMMDD)
    sls_due_dt      INT,            -- Payment/Delivery due date in integer format
    sls_sales       INT,            -- Total sales amount
    sls_quantity    INT,            -- Quantity of units ordered
    sls_price       INT             -- Unit selling price
);
GO


-- =============================================================================
-- 2. ERP TABLES (Demographics, Location, Category Mapping)
-- =============================================================================

-------------------------------------------------------------------------------
-- Table: bronze.erp_cust_az12
-- Description: Customer demographics and birth dates exported from ERP module AZ12.
-------------------------------------------------------------------------------
IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL 
    DROP TABLE bronze.erp_cust_az12;
GO

CREATE TABLE bronze.erp_cust_az12 (
    CID     NVARCHAR(50),   -- Customer identifier from ERP system
    BDATE   DATE,           -- Customer birth date
    GEN     NVARCHAR(50)    -- Customer gender code/description
);
GO


-------------------------------------------------------------------------------
-- Table: bronze.erp_loc_a101
-- Description: Customer regional and country data from ERP module A101.
-------------------------------------------------------------------------------
IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL 
    DROP TABLE bronze.erp_loc_a101;
GO

CREATE TABLE bronze.erp_loc_a101 (
    CID     NVARCHAR(50),   -- Customer identifier from ERP system
    CNTRY   NVARCHAR(50)    -- Country name or ISO country code
);
GO


-------------------------------------------------------------------------------
-- Table: bronze.erp_px_cat_g1v2
-- Description: Product category hierarchy and maintenance codes from ERP module G1V2.
-------------------------------------------------------------------------------
IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL 
    DROP TABLE bronze.erp_px_cat_g1v2;
GO

CREATE TABLE bronze.erp_px_cat_g1v2 (
    ID            NVARCHAR(50),   -- Product category identifier / Key
    CAT           NVARCHAR(50),   -- Product category name
    SUBCAT        NVARCHAR(50),   -- Product sub-category name
    MAINTENANCE   NVARCHAR(50)    -- Maintenance / Service classification
);
GO
