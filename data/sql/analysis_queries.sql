/* =====================================================================
   Financial Crime and Credit Risk Analytics: SQL query pack
   Run these against the CSVs loaded into MySQL or PostgreSQL.
   Each query reproduces one finding in the project report.
   Ordered from basic to advanced so you can learn as you go.
   ===================================================================== */


/* ---------- 1. Customer base by risk rating (SELECT + GROUP BY) ------ */
SELECT  risk_rating,
        COUNT(*) AS customers,
        ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_book
FROM    customers
GROUP BY risk_rating
ORDER BY customers DESC;


/* ---------- 2. Turnaround and SLA breach by due diligence level ------ */
SELECT  due_diligence_level,
        COUNT(*)                                              AS cases,
        ROUND(AVG(days_taken), 1)                             AS avg_days,
        MAX(sla_days)                                         AS sla_target,
        ROUND(100.0 * SUM(CASE WHEN sla_breached = 'Y'
                               THEN 1 ELSE 0 END) / COUNT(*), 1) AS sla_breach_pct
FROM    cdd_kyc_cases
WHERE   days_taken IS NOT NULL
GROUP BY due_diligence_level
ORDER BY avg_days DESC;


/* ---------- 3. Onboarding vs periodic review (the backlog story) ----- */
SELECT  case_type,
        COUNT(*)                  AS cases,
        ROUND(AVG(days_taken), 1) AS avg_days,
        SUM(CASE WHEN status = 'Pending' THEN 1 ELSE 0 END) AS still_open
FROM    cdd_kyc_cases
GROUP BY case_type;


/* ---------- 4. Why cases are rejected -------------------------------- */
SELECT  rejection_reason, COUNT(*) AS cases
FROM    cdd_kyc_cases
WHERE   status = 'Rejected'
GROUP BY rejection_reason
ORDER BY cases DESC;


/* ---------- 5. Quality assurance failure rate ------------------------ */
SELECT  ROUND(100.0 * SUM(CASE WHEN qa_check_passed = 'N' THEN 1 ELSE 0 END)
              / COUNT(qa_check_passed), 1) AS qa_fail_pct
FROM    cdd_kyc_cases;


/* ---------- 6. Complex ownership structures (JOIN + CASE) ------------ */
SELECT  b.complex_structure_flag,
        COUNT(*)                                                   AS reviews,
        ROUND(100.0 * SUM(CASE WHEN b.ubo_identified = 'N'
                               THEN 1 ELSE 0 END) / COUNT(*), 1)    AS ubo_not_identified_pct,
        ROUND(100.0 * SUM(CASE WHEN b.bdd_outcome = 'Rejected'
                               THEN 1 ELSE 0 END) / COUNT(*), 1)    AS rejected_pct
FROM    business_due_diligence b
GROUP BY b.complex_structure_flag;


/* ---------- 7. Screening false positives ----------------------------- */
SELECT  COUNT(*)                                                       AS screenings,
        SUM(CASE WHEN disposition <> 'No Hit' THEN 1 ELSE 0 END)       AS hits,
        SUM(CASE WHEN sanctions_true_match = 'Y' THEN 1 ELSE 0 END)    AS true_sanctions_matches,
        SUM(CASE WHEN adverse_media_relevant = 'Y' THEN 1 ELSE 0 END)  AS relevant_adverse_media,
        ROUND(100.0 * SUM(CASE WHEN disposition = 'Cleared - False Positive' THEN 1 ELSE 0 END)
              / NULLIF(SUM(CASE WHEN disposition <> 'No Hit' THEN 1 ELSE 0 END), 0), 1)
                                                                       AS false_positive_pct
FROM    external_screening;


/* ---------- 8. What the confirmed adverse media is actually about ---- */
SELECT  adverse_media_category, COUNT(*) AS hits
FROM    external_screening
WHERE   adverse_media_hit = 'Y'
GROUP BY adverse_media_category
ORDER BY hits DESC;


/* ---------- 9. AML alert outcomes and analyst effort by scenario ----- */
SELECT  scenario,
        COUNT(*)                                                        AS alerts,
        ROUND(100.0 * SUM(CASE WHEN outcome = 'Closed - False Positive'
                               THEN 1 ELSE 0 END) / COUNT(*), 1)        AS false_positive_pct,
        SUM(CASE WHEN sar_filed = 'Y' THEN 1 ELSE 0 END)                AS sars_filed,
        ROUND(SUM(analyst_hours), 0)                                    AS analyst_hours
FROM    aml_alerts
WHERE   status = 'Closed'
GROUP BY scenario
ORDER BY analyst_hours DESC;


/* ---------- 10. Hours lost to false positives ------------------------ */
SELECT  ROUND(SUM(CASE WHEN outcome = 'Closed - False Positive'
                       THEN analyst_hours ELSE 0 END), 0)               AS false_positive_hours,
        ROUND(SUM(analyst_hours), 0)                                    AS total_hours,
        ROUND(100.0 * SUM(CASE WHEN outcome = 'Closed - False Positive'
                               THEN analyst_hours ELSE 0 END)
              / SUM(analyst_hours), 1)                                  AS pct_wasted
FROM    aml_alerts
WHERE   status = 'Closed';


/* ---------- 11. Alerts generated per customer, by risk rating -------- */
SELECT  c.risk_rating,
        COUNT(DISTINCT c.customer_id)                                   AS customers,
        COUNT(a.alert_id)                                               AS alerts,
        ROUND(1.0 * COUNT(a.alert_id) / COUNT(DISTINCT c.customer_id), 1) AS alerts_per_customer
FROM    customers c
LEFT JOIN aml_alerts a ON a.customer_id = c.customer_id
GROUP BY c.risk_rating
ORDER BY alerts_per_customer DESC;


/* ---------- 12. Budget variance and cost-to-income by branch (CTE) --- */
WITH cost AS (
    SELECT branch_id, SUM(actual_gbp) AS actual, SUM(budget_gbp) AS budget
    FROM   operating_costs GROUP BY branch_id
),
income AS (
    SELECT branch_id, SUM(total_income_gbp) AS income
    FROM   branch_income GROUP BY branch_id
)
SELECT  b.branch_name,
        c.actual,
        c.budget,
        ROUND(100.0 * (c.actual - c.budget) / c.budget, 1) AS variance_pct,
        ROUND(100.0 * c.actual / i.income, 1)              AS cost_to_income_pct
FROM    cost c
JOIN    income i  ON i.branch_id = c.branch_id
JOIN    branches b ON b.branch_id = c.branch_id
ORDER BY variance_pct DESC;


/* ---------- 13. Year-on-year cost growth by department (window fn) --- */
WITH yearly AS (
    SELECT department,
           EXTRACT(YEAR FROM month) AS yr,      -- MySQL: YEAR(month)
           SUM(actual_gbp)          AS actual
    FROM   operating_costs
    GROUP BY department, EXTRACT(YEAR FROM month)
)
SELECT  department, yr, actual,
        LAG(actual) OVER (PARTITION BY department ORDER BY yr) AS prior_year,
        ROUND(100.0 * (actual - LAG(actual) OVER (PARTITION BY department ORDER BY yr))
              / LAG(actual) OVER (PARTITION BY department ORDER BY yr), 1) AS growth_pct
FROM    yearly
ORDER BY department, yr;


/* ---------- 14. Credit quality by score band ------------------------- */
SELECT  credit_score_band,
        COUNT(*)                                                       AS loans,
        SUM(exposure_gbp)                                              AS exposure_gbp,
        ROUND(100.0 * SUM(CASE WHEN default_flag = 'Y'
                               THEN 1 ELSE 0 END) / COUNT(*), 2)       AS default_rate_pct,
        SUM(expected_credit_loss_gbp)                                  AS ecl_gbp
FROM    loan_portfolio
GROUP BY credit_score_band
ORDER BY default_rate_pct DESC;


/* ---------- 15. THE HEADLINE: AML risk rating vs credit default ------ */
SELECT  c.risk_rating,
        COUNT(l.loan_id)                                               AS loans,
        SUM(l.exposure_gbp)                                            AS exposure_gbp,
        ROUND(100.0 * SUM(CASE WHEN l.default_flag = 'Y'
                               THEN 1 ELSE 0 END) / COUNT(*), 2)       AS default_rate_pct
FROM    loan_portfolio l
JOIN    customers c ON c.customer_id = l.customer_id
GROUP BY c.risk_rating
ORDER BY default_rate_pct DESC;


/* ---------- 16. Lending exposure to customers with a filed SAR ------- */
SELECT  COUNT(DISTINCT l.customer_id) AS customers_with_sar_and_lending,
        COUNT(l.loan_id)              AS loans,
        SUM(l.exposure_gbp)           AS exposure_at_risk_gbp
FROM    loan_portfolio l
WHERE   l.customer_id IN (SELECT customer_id FROM aml_alerts WHERE sar_filed = 'Y');


/* ---------- 17. Concentration risk: top sectors (RANK) --------------- */
SELECT  sector,
        SUM(exposure_gbp)                                              AS exposure_gbp,
        ROUND(100.0 * SUM(exposure_gbp) / SUM(SUM(exposure_gbp)) OVER (), 1) AS pct_of_book,
        RANK() OVER (ORDER BY SUM(exposure_gbp) DESC)                  AS concentration_rank
FROM    loan_portfolio
GROUP BY sector
ORDER BY concentration_rank
LIMIT 10;


/* ---------- 18. IFRS 9 staging summary ------------------------------- */
SELECT  ifrs9_stage,
        COUNT(*)                                       AS loans,
        SUM(exposure_gbp)                              AS exposure_gbp,
        SUM(expected_credit_loss_gbp)                  AS ecl_gbp,
        ROUND(100.0 * SUM(expected_credit_loss_gbp)
              / SUM(exposure_gbp), 2)                  AS coverage_pct
FROM    loan_portfolio
GROUP BY ifrs9_stage
ORDER BY ifrs9_stage;
