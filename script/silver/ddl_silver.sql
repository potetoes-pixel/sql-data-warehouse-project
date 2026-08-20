/*
=================================================================================
DDL Script: Create Silver Layer Tables
=================================================================================
Source Systems:
    1. CRM (Customer Relationship Management)
    2. ERP (Enterprise Resource Planning)

Purpose:
    Cleansed, transformed, and standardized Silver layer data structures.
===============================================================================
*/

-- =============================================================================
-- 1. CRM TABLES (Customer, Product, Sales)
-- =============================================================================

---------------------------------------------------------------------------------
-- Table: silver.crm_cust_info
-- Description: Stores customer demographic and profile information from CRM.
---------------------------------------------------------------------------------
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL 
    DROP TABLE silver.crm_cust_info;
GO

CREATE TABLE silver.crm_cust_info (
    cst_id               INT,            -- Unique identifier / primary key for the customer
    cst_key              NVARCHAR(50),   -- Business/Alternate key used across source systems
    cst_firstname        NVARCHAR(50),   -- Customer's first name
    cst_lastname         NVARCHAR(50),   -- Customer's last name
    cst_marital_status   NVARCHAR(50),   -- Standardized marital status (e.g., Single, Married)
    cst_gndr             NVARCHAR(50),   -- Standardized gender representation (e.g., Male, Female)
    cst_create_date      DATE,           -- Date when the customer record was originally created
    dwh_create_date      DATETIME2 DEFAULT GETDATE() -- Timestamp of record insertion into the data warehouse
);
GO

---------------------------------------------------------------------------------
-- Table: silver.crm_prd_info
-- Description: Stores product catalog, pricing, and lifecycle dates from CRM.
---------------------------------------------------------------------------------
IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL 
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info (
    prd_id               INT,            -- Unique internal identifier for the product
    cat_id               NVARCHAR(50),   -- Changed
    prd_key              NVARCHAR(50),   -- Business key / SKU used across systems
    prd_nm               NVARCHAR(50),   -- Product name or catalog description
    prd_cost             INT,            -- Base manufacturing or unit cost
    prd_line             NVARCHAR(50),   -- Product line or high-level category identifier
    prd_start_dt         DATE,           -- Effective start date of product availability
    prd_end_dt           DATE,           -- Sunset/discontinuation date of the product
    dwh_create_date      DATETIME2 DEFAULT GETDATE() -- Timestamp of record insertion into the data warehouse
);
GO

---------------------------------------------------------------------------------
-- Table: silver.crm_sales_details
-- Description: Stores transactional sales order line items from CRM.
---------------------------------------------------------------------------------
IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL 
    DROP TABLE silver.crm_sales_details;
GO

CREATE TABLE silver.crm_sales_details (
    sls_ord_num          NVARCHAR(50),   -- Unique sales order number / transaction reference
    sls_prd_key          NVARCHAR(50),   -- Foreign reference to the product key (silver.crm_prd_info)
    sls_cust_id          INT,            -- Foreign reference to the customer ID (silver.crm_cust_info)
    sls_order_dt         DATE,           -- Order placement date in integer format (YYYYMMDD)
    sls_ship_dt          DATE,           -- Order shipment date in integer format (YYYYMMDD)
    sls_due_dt           DATE,           -- Payment/delivery due date in integer format (YYYYMMDD)
    sls_sales            INT,            -- Total net sales transaction amount
    sls_quantity         INT,            -- Total quantity of units purchased
    sls_price            INT,            -- Unit price charged per item
    dwh_create_date      DATETIME2 DEFAULT GETDATE() -- Timestamp of record insertion into the data warehouse
);
GO

-- =============================================================================
-- 2. ERP TABLES (Demographics, Location, Category Mapping)
-- =============================================================================

---------------------------------------------------------------------------------
-- Table: silver.erp_cust_az12
-- Description: Customer demographics and birth dates exported from ERP module AZ12.
---------------------------------------------------------------------------------
IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL 
    DROP TABLE silver.erp_cust_az12;
GO

CREATE TABLE silver.erp_cust_az12 (
    CID                  NVARCHAR(50),   -- ERP customer identifier (maps to cst_key)
    BDATE                DATE,           -- Customer date of birth
    GEN                  NVARCHAR(50),   -- Raw or standardized customer gender code
    dwh_create_date      DATETIME2 DEFAULT GETDATE() -- Timestamp of record insertion into the data warehouse
);
GO

---------------------------------------------------------------------------------
-- Table: silver.erp_loc_a101
-- Description: Customer regional and country data from ERP module A101.
---------------------------------------------------------------------------------
IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL 
    DROP TABLE silver.erp_loc_a101;
GO

CREATE TABLE silver.erp_loc_a101 (
    CID                  NVARCHAR(50),   -- ERP customer identifier (maps to cst_key)
    CNTRY                NVARCHAR(50),   -- Country name or standardized country code
    dwh_create_date      DATETIME2 DEFAULT GETDATE() -- Timestamp of record insertion into the data warehouse
);
GO

---------------------------------------------------------------------------------
-- Table: silver.erp_px_cat_g1v2
-- Description: Product category hierarchy and maintenance codes from ERP module G1V2.
---------------------------------------------------------------------------------
IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL 
    DROP TABLE silver.erp_px_cat_g1v2;
GO

CREATE TABLE silver.erp_px_cat_g1v2 (
    ID                   NVARCHAR(50),   -- Category/Product reference key (maps to prd_line)
    CAT                  NVARCHAR(50),   -- High-level product category name
    SUBCAT               NVARCHAR(50),   -- Detailed product sub-category name
    MAINTENANCE          NVARCHAR(50),   -- Maintenance level or warranty classification code
    dwh_create_date      DATETIME2 DEFAULT GETDATE() -- Timestamp of record insertion into the data warehouse
);
GO
