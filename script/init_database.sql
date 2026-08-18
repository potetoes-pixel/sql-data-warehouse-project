/*
===============================================================================
Database & Schema Setup Script: DataWarehouse
===============================================================================

Script Purpose:
    This script initializes the 'DataWarehouse' database and creates the core 
    schemas following the Medallion Architecture (Bronze, Silver, Gold layers).

Notes:
    - 'GO' is used to separate statements into distinct batches in SQL Server (T-SQL

===============================================================================
!!! WARNING: DATA LOSS RISK !!!
===============================================================================
If enabled, the DROP DATABASE logic below will PERMANENTLY DELETE the 
'DataWarehouse' database and ALL tables, views, stored procedures, and data 
contained within it.
===============================================================================
*/

-- Switch context to the master system database to safely manage database creation
USE master;
GO

-- Drop database if it already exists (Optional safety check)
/*
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO
*/

-- Create the target Data Warehouse database
CREATE DATABASE DataWarehouse;
GO

-- Switch context to the newly created 'DataWarehouse' database
USE DataWarehouse;
GO

-- ============================================================================
-- Create Schemas for Medallion Architecture
-- ============================================================================

-- 1. Bronze Layer (Raw Data Layer)
-- Stores raw, ingested source data as-is with minimal or no transformations.
CREATE SCHEMA bronze;
GO

-- 2. Silver Layer (Cleaned & Conformed Layer)
-- Stores cleaned, filtered, standardized, and enriched data.
CREATE SCHEMA silver;
GO

-- 3. Gold Layer (Curated / Business Layer)
-- Stores dimensional models (star/snowflake schemas, facts, and dimensions) 
-- optimized for reporting, analytics, and business intelligence (BI).
CREATE SCHEMA gold;
GO
