-- 🔍 Check your data (preview first 10 rows)
SELECT TOP 10 * FROM loans;
SELECT TOP 10 * FROM customers;
SELECT TOP 10 * FROM payments;

-----------------------------------------------------------
--  KPI 1: Total Loans Issued Per Month
-----------------------------------------------------------
SELECT 
    FORMAT(CAST(issue_date AS DATE), 'yyyy-MM') AS month,
    COUNT(*) AS total_loans_issued
FROM 
    loans
GROUP BY 
    FORMAT(CAST(issue_date AS DATE), 'yyyy-MM')
ORDER BY 
    month;

-----------------------------------------------------------
-- KPI 2: Average Loan Size by Customer Segment
-----------------------------------------------------------
SELECT 
    c.segment,
    COUNT(l.loan_id) AS total_loans,
    AVG(CAST(l.loan_amount AS FLOAT)) AS avg_loan_amount
FROM 
    customers c
JOIN 
    loans l ON c.customer_id = l.customer_id
GROUP BY 
    c.segment
ORDER BY 
    avg_loan_amount DESC;

-----------------------------------------------------------
--  KPI 4: Customer Lifetime Value (LTV)
-----------------------------------------------------------
SELECT 
    cu.customer_id,
    cu.name,
    cu.segment,
    ISNULL(cl.total_borrowed, 0) AS total_borrowed,
    ISNULL(cp.total_paid, 0) AS total_paid,
    ROUND(
        CASE 
            WHEN ISNULL(cl.total_borrowed, 0) = 0 THEN NULL
            ELSE ISNULL(cp.total_paid, 0) / NULLIF(cl.total_borrowed, 0)
        END, 2
    ) AS ltv_ratio
FROM customers cu

LEFT JOIN (
    SELECT 
        customer_id,
        SUM(CAST(loan_amount AS FLOAT)) AS total_borrowed
    FROM loans
    GROUP BY customer_id
) cl ON cu.customer_id = cl.customer_id

LEFT JOIN (
    SELECT 
        l.customer_id,
        SUM(CAST(p.amount_paid AS FLOAT)) AS total_paid
    FROM payments p
    JOIN loans l ON p.loan_id = l.loan_id
    GROUP BY l.customer_id
) cp ON cu.customer_id = cp.customer_id

ORDER BY ltv_ratio DESC;

SELECT TOP 10
    cu.customer_id,
    cu.name,
    cu.segment,
    ISNULL(cl.total_borrowed, 0) AS total_borrowed,
    ISNULL(cp.total_paid, 0) AS total_paid,
    ROUND(
        CASE 
            WHEN ISNULL(cl.total_borrowed, 0) = 0 THEN NULL
            ELSE (ISNULL(cp.total_paid, 0) - cl.total_borrowed) / NULLIF(cl.total_borrowed, 0)
        END, 2
    ) AS roi
FROM customers cu

LEFT JOIN (
    SELECT 
        customer_id,
        SUM(CAST(loan_amount AS FLOAT)) AS total_borrowed
    FROM loans
    GROUP BY customer_id
) cl ON cu.customer_id = cl.customer_id

LEFT JOIN (
    SELECT 
        l.customer_id,
        SUM(CAST(p.amount_paid AS FLOAT)) AS total_paid
    FROM payments p
    JOIN loans l ON p.loan_id = l.loan_id
    GROUP BY l.customer_id
) cp ON cu.customer_id = cp.customer_id

ORDER BY roi DESC;

-- Step 1: Monthly payments
WITH monthly_payments AS (
    SELECT 
        FORMAT(CAST(payment_date AS DATE), 'yyyy-MM') AS pay_month,
        SUM(CAST(amount_paid AS FLOAT)) AS total_paid
    FROM payments
    GROUP BY FORMAT(CAST(payment_date AS DATE), 'yyyy-MM')
),

-- Step 2: Monthly loans
monthly_loans AS (
    SELECT 
        FORMAT(CAST(issue_date AS DATE), 'yyyy-MM') AS loan_month,
        SUM(CAST(loan_amount AS FLOAT)) AS total_issued
    FROM loans
    GROUP BY FORMAT(CAST(issue_date AS DATE), 'yyyy-MM')
)

-- Step 3: Rolling 3-month coverage
SELECT 
    mp.pay_month,
    mp.total_paid,
    (
        SELECT SUM(ml.total_issued)
        FROM monthly_loans ml
        WHERE ml.loan_month BETWEEN FORMAT(DATEADD(MONTH, -3, CAST(mp.pay_month + '-01' AS DATE)), 'yyyy-MM') 
                                AND FORMAT(DATEADD(MONTH, -1, CAST(mp.pay_month + '-01' AS DATE)), 'yyyy-MM')
    ) AS total_issued_last_3_months,
    ROUND(
        CASE 
            WHEN (
                SELECT SUM(ml.total_issued)
                FROM monthly_loans ml
                WHERE ml.loan_month BETWEEN FORMAT(DATEADD(MONTH, -3, CAST(mp.pay_month + '-01' AS DATE)), 'yyyy-MM') 
                                        AND FORMAT(DATEADD(MONTH, -1, CAST(mp.pay_month + '-01' AS DATE)), 'yyyy-MM')
            ) = 0 THEN NULL
            ELSE mp.total_paid / 
            (
                SELECT SUM(ml.total_issued)
                FROM monthly_loans ml
                WHERE ml.loan_month BETWEEN FORMAT(DATEADD(MONTH, -3, CAST(mp.pay_month + '-01' AS DATE)), 'yyyy-MM') 
                                        AND FORMAT(DATEADD(MONTH, -1, CAST(mp.pay_month + '-01' AS DATE)), 'yyyy-MM')
            )
        END, 2
    ) AS coverage_ratio
FROM monthly_payments mp
ORDER BY mp.pay_month;

-- Step 1: Total payments per loan
WITH loan_payments AS (
    SELECT 
        loan_id,
        SUM(CAST(amount_paid AS FLOAT)) AS total_paid
    FROM payments
    GROUP BY loan_id
),

-- Step 2: Join with loans and classify
loan_status AS (
    SELECT 
        l.loan_id,
        l.loan_amount,
        ISNULL(lp.total_paid, 0) AS total_paid,
        CASE 
            WHEN ISNULL(lp.total_paid, 0) >= CAST(l.loan_amount AS FLOAT) THEN 'Paid Off'
            ELSE 'Active'
        END AS status
    FROM loans l
    LEFT JOIN loan_payments lp ON l.loan_id = lp.loan_id
)

-- Step 3: Count by status
SELECT 
    status,
    COUNT(*) AS loan_count
FROM loan_status
GROUP BY status;


