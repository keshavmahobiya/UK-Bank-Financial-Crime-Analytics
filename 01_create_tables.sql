/* Loading the data into PostgreSQL or MySQL
   ----------------------------------------------------------------
   Easiest route: use the import wizard in pgAdmin, MySQL Workbench
   or DBeaver, point it at each CSV in /data, and let it create the
   table with the file name as the table name.

   If you prefer to create tables yourself, the pattern below works.
   Repeat it for each CSV, matching the column names in the file.
   ---------------------------------------------------------------- */

CREATE TABLE customers (
    customer_id                   VARCHAR(10) PRIMARY KEY,
    customer_name                 VARCHAR(100),
    customer_type                 VARCHAR(20),
    country_of_residence          VARCHAR(50),
    occupation_or_industry        VARCHAR(50),
    branch_id                     VARCHAR(10),
    onboarding_channel            VARCHAR(30),
    risk_rating                   VARCHAR(10),
    pep_flag                      CHAR(1),
    annual_income_or_turnover_gbp BIGINT,
    relationship_start_date       DATE
);

/* PostgreSQL bulk load (run as a superuser, or use \copy in psql) */
-- COPY customers FROM '/full/path/to/customers.csv' DELIMITER ',' CSV HEADER;

/* MySQL bulk load */
-- LOAD DATA INFILE '/full/path/to/customers.csv'
-- INTO TABLE customers
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"'
-- LINES TERMINATED BY '\n' IGNORE 1 ROWS;

/* Recommended indexes once every table is loaded */
-- CREATE INDEX idx_cases_customer   ON cdd_kyc_cases (customer_id);
-- CREATE INDEX idx_alerts_customer  ON aml_alerts (customer_id);
-- CREATE INDEX idx_loans_customer   ON loan_portfolio (customer_id);
-- CREATE INDEX idx_screening_cust   ON external_screening (customer_id);
