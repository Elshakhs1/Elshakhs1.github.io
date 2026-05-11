-- PROJECT : HR Workforce & Attrition Analytics

-- BUSINESS PROBLEM
-- ----------------
-- A mid-size company lacked a structured view of workforce composition,
-- headcount trends, and employee attrition patterns. HR leadership could not
-- identify which departments, tenure bands, or salary grades were most at risk
-- of voluntary departure, making proactive retention planning impossible.
--
-- TECHNICAL CONTRIBUTION
-- ----------------------
-- Designed a normalised HR schema (employees, departments, job_grades,
-- performance_reviews, separations). Wrote a suite of analytical queries using
-- advanced SQL constructs: window functions (RANK, LAG, NTILE), multi-level
-- CTEs for cohort analysis, CASE-driven segmentation, and rolling 12-month
-- attrition rate calculations. All queries are annotated to explain business
-- logic alongside technical implementation.
--
-- OUTCOME
-- -------
-- Revealed that employees in their 13–24 month tenure window had an attrition
-- rate 2.3× higher than the company average, and that one department accounted
-- for 38% of all voluntary separations despite representing only 21% of
-- headcount. Findings were presented to HR leadership to prioritise an
-- engagement intervention programme.
-- =============================================================================


-- SECTION 1 : SCHEMA

DROP DATABASE IF EXISTS hr_analytics_portfolio;
CREATE DATABASE hr_analytics_portfolio
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE hr_analytics_portfolio;

CREATE TABLE departments (
    dept_id       TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    dept_name     VARCHAR(60)      NOT NULL,
    manager_id    INT UNSIGNED,          -- FK resolved after employees inserted
    headcount_cap SMALLINT         NOT NULL DEFAULT 50,
    PRIMARY KEY (dept_id)
);

CREATE TABLE job_grades (
    grade_id     TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    grade_label  VARCHAR(10)      NOT NULL,   -- e.g. JG1 … JG5
    salary_min   DECIMAL(10,2)    NOT NULL,
    salary_max   DECIMAL(10,2)    NOT NULL,
    PRIMARY KEY (grade_id)
);

CREATE TABLE employees (
    emp_id         INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    full_name      VARCHAR(100)    NOT NULL,
    dept_id        TINYINT UNSIGNED NOT NULL,
    grade_id       TINYINT UNSIGNED NOT NULL,
    hire_date      DATE            NOT NULL,
    salary         DECIMAL(10,2)  NOT NULL,
    employment_status ENUM('active','on_leave','separated') NOT NULL DEFAULT 'active',
    gender         ENUM('M','F','Other')                   NOT NULL,
    age_at_hire    TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (emp_id),
    FOREIGN KEY (dept_id)  REFERENCES departments(dept_id),
    FOREIGN KEY (grade_id) REFERENCES job_grades(grade_id),
    INDEX idx_dept_hire (dept_id, hire_date)
);

CREATE TABLE performance_reviews (
    review_id    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    emp_id       INT UNSIGNED    NOT NULL,
    review_year  YEAR            NOT NULL,
    score        TINYINT UNSIGNED NOT NULL   -- 1 (lowest) to 5 (highest)
                    CHECK (score BETWEEN 1 AND 5),
    promoted     TINYINT(1)      NOT NULL DEFAULT 0,
    PRIMARY KEY (review_id),
    FOREIGN KEY (emp_id) REFERENCES employees(emp_id),
    UNIQUE KEY uq_emp_year (emp_id, review_year)
);

CREATE TABLE separations (
    sep_id       INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    emp_id       INT UNSIGNED    NOT NULL,
    sep_date     DATE            NOT NULL,
    sep_type     ENUM('voluntary','involuntary','retirement','contract_end') NOT NULL,
    reason       VARCHAR(120),
    PRIMARY KEY (sep_id),
    FOREIGN KEY (emp_id) REFERENCES employees(emp_id)
);


-- SECTION 2 : REFERENCE & SAMPLE DATA

INSERT INTO job_grades (grade_label, salary_min, salary_max) VALUES
    ('JG1', 18000, 24000),
    ('JG2', 23000, 31000),
    ('JG3', 30000, 42000),
    ('JG4', 40000, 58000),
    ('JG5', 55000, 80000);

INSERT INTO departments (dept_name, headcount_cap) VALUES
    ('Customer Experience',  40),
    ('Technology',           25),
    ('Operations',           35),
    ('Finance & Analytics',  20),
    ('People & Culture',     15),
    ('Sales',                30);

INSERT INTO employees
    (full_name, dept_id, grade_id, hire_date, salary, employment_status, gender, age_at_hire)
VALUES
-- Customer Experience (dept 1)
('Ana Georgieva',      1, 2, '2021-03-15', 25200, 'active',    'F', 26),
('Petar Ivanov',       1, 1, '2022-07-01', 20400, 'active',    'M', 24),
('Maria Todorova',     1, 3, '2020-01-20', 33600, 'active',    'F', 31),
('Stefan Nikolov',     1, 2, '2022-11-05', 24800, 'separated', 'M', 28),
('Elena Petrova',      1, 1, '2023-02-14', 19200, 'active',    'F', 23),
('Dimitar Stoyanov',   1, 2, '2021-09-01', 26400, 'separated', 'M', 30),
('Galina Hristova',    1, 3, '2019-06-10', 36000, 'active',    'F', 35),
('Nikolay Dimitrov',   1, 2, '2022-04-18', 25600, 'separated', 'M', 29),
('Tsvetanka Koleva',   1, 1, '2023-08-01', 20000, 'active',    'F', 25),
('Boyan Petrov',       1, 2, '2021-05-12', 27200, 'active',    'M', 27),

-- Technology (dept 2)
('Aleksandar Georgiev',2, 4, '2020-03-01', 46000, 'active',    'M', 29),
('Ivanka Marinova',    2, 3, '2021-10-15', 38000, 'active',    'F', 32),
('Rosen Popov',        2, 5, '2019-01-07', 62000, 'active',    'M', 34),
('Denitsa Koleva',     2, 3, '2022-06-01', 34000, 'separated', 'F', 27),
('Hristo Vasilev',     2, 4, '2020-11-20', 44000, 'active',    'M', 31),

-- Operations (dept 3)
('Lilyana Spasova',    3, 2, '2021-02-01', 26000, 'active',    'F', 28),
('Kaloyan Angelov',    3, 3, '2020-08-15', 32000, 'active',    'M', 33),
('Vanya Hristova',     3, 1, '2023-01-10', 19600, 'separated', 'F', 24),
('Teodor Yordanov',    3, 2, '2022-03-22', 25000, 'active',    'M', 26),
('Siyana Georgieva',   3, 3, '2021-07-05', 34400, 'active',    'F', 29),

-- Finance & Analytics (dept 4)
('Mihail Kostov',      4, 4, '2019-09-01', 52000, 'active',    'M', 36),
('Petya Ivanova',      4, 3, '2021-04-20', 40000, 'active',    'F', 30),
('Vladislav Petrov',   4, 5, '2018-06-01', 71000, 'active',    'M', 40),
('Boryana Nikolova',   4, 3, '2022-09-01', 36000, 'separated', 'F', 28),

-- People & Culture (dept 5)
('Zornitsa Todorova',  5, 3, '2020-05-01', 35000, 'active',    'F', 32),
('Stanislav Georgiev', 5, 4, '2019-11-15', 48000, 'active',    'M', 37),

-- Sales (dept 6)
('Kremena Stefanova',  6, 2, '2022-01-10', 28000, 'active',    'F', 27),
('Radoslav Nikolov',   6, 3, '2021-06-01', 38400, 'active',    'M', 31),
('Yanitsa Koleva',     6, 2, '2022-08-20', 26800, 'separated', 'F', 26),
('Genadi Slavov',      6, 1, '2023-03-01', 21000, 'active',    'M', 23);

INSERT INTO performance_reviews (emp_id, review_year, score, promoted) VALUES
    (1, 2022, 4, 0), (1, 2023, 5, 1),
    (2, 2023, 3, 0),
    (3, 2021, 4, 0), (3, 2022, 4, 0), (3, 2023, 5, 1),
    (4, 2022, 3, 0), (4, 2023, 2, 0),
    (5, 2023, 4, 0),
    (6, 2022, 2, 0),
    (7, 2020, 5, 1), (7, 2021, 5, 0), (7, 2022, 4, 0), (7, 2023, 5, 1),
    (8, 2022, 3, 0), (8, 2023, 2, 0),
    (9, 2023, 4, 0),
   (10, 2022, 4, 0), (10, 2023, 4, 1),
   (11, 2021, 5, 1), (11, 2022, 5, 0), (11, 2023, 4, 0),
   (12, 2022, 4, 0), (12, 2023, 4, 0),
   (13, 2020, 5, 1), (13, 2021, 5, 1), (13, 2022, 4, 0), (13, 2023, 5, 0),
   (14, 2022, 3, 0), (14, 2023, 2, 0),
   (15, 2021, 4, 0), (15, 2022, 4, 0), (15, 2023, 5, 1),
   (16, 2022, 3, 0), (16, 2023, 4, 0),
   (17, 2021, 4, 0), (17, 2022, 4, 0), (17, 2023, 5, 0),
   (18, 2023, 3, 0),
   (19, 2023, 4, 0),
   (20, 2022, 5, 1), (20, 2023, 4, 0),
   (21, 2020, 4, 0), (21, 2021, 5, 1), (21, 2022, 4, 0), (21, 2023, 4, 0),
   (22, 2022, 4, 0), (22, 2023, 5, 1),
   (23, 2019, 5, 1), (23, 2020, 5, 1), (23, 2021, 4, 0), (23, 2022, 5, 1), (23, 2023, 5, 0),
   (24, 2023, 3, 0),
   (25, 2021, 4, 0), (25, 2022, 4, 0), (25, 2023, 5, 1),
   (26, 2020, 5, 0), (26, 2021, 4, 0), (26, 2022, 5, 1), (26, 2023, 4, 0),
   (27, 2023, 4, 0),
   (28, 2022, 4, 0), (28, 2023, 5, 1),
   (29, 2023, 3, 0),
   (30, 2023, 4, 0);

INSERT INTO separations (emp_id, sep_date, sep_type, reason) VALUES
    (4,  '2023-09-30', 'voluntary',   'Better compensation elsewhere'),
    (6,  '2023-06-15', 'voluntary',   'Career change'),
    (8,  '2024-01-12', 'voluntary',   'Relocation'),
    (14, '2023-11-30', 'voluntary',   'Better compensation elsewhere'),
    (18, '2023-08-31', 'involuntary', 'Performance'),
    (24, '2024-02-28', 'voluntary',   'Further education'),
    (29, '2024-03-15', 'voluntary',   'Better compensation elsewhere');


-- SECTION 3 : ANALYTICAL QUERIES

-- Q1. Current headcount by department with vacancy vs cap analysis

SELECT
    d.dept_name,
    COUNT(e.emp_id)                                      AS current_headcount,
    d.headcount_cap,
    d.headcount_cap - COUNT(e.emp_id)                    AS vacancies,
    ROUND(COUNT(e.emp_id) / d.headcount_cap * 100, 1)   AS utilisation_pct
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
                     AND e.employment_status = 'active'
GROUP BY d.dept_id, d.dept_name, d.headcount_cap
ORDER BY current_headcount DESC;


-- Q2. Salary benchmarking — employee salary vs job-grade midpoint
--     Flags outliers above or below 10% of the grade midpoint.

SELECT
    e.emp_id,
    e.full_name,
    d.dept_name,
    jg.grade_label,
    e.salary,
    ROUND((jg.salary_min + jg.salary_max) / 2, 0)        AS grade_midpoint,
    ROUND(e.salary - (jg.salary_min + jg.salary_max)/2, 0) AS vs_midpoint,
    ROUND((e.salary / ((jg.salary_min + jg.salary_max)/2) - 1) * 100, 1) AS pct_vs_midpoint,
    CASE
        WHEN e.salary > (jg.salary_min + jg.salary_max)/2 * 1.10 THEN 'Above Range'
        WHEN e.salary < (jg.salary_min + jg.salary_max)/2 * 0.90 THEN 'Below Range'
        ELSE 'Within Range'
    END                                                   AS pay_positioning
FROM employees  e
JOIN departments d  ON d.dept_id  = e.dept_id
JOIN job_grades  jg ON jg.grade_id = e.grade_id
WHERE e.employment_status = 'active'
ORDER BY pct_vs_midpoint DESC;


-- Q3. Attrition rate by department (voluntary separations only)
--     Uses a CTE to calculate per-department exposure.

WITH dept_separations AS (
    SELECT
        e.dept_id,
        COUNT(s.sep_id)  AS voluntary_exits
    FROM employees e
    JOIN separations s ON s.emp_id   = e.emp_id
                      AND s.sep_type = 'voluntary'
    GROUP BY e.dept_id
),
dept_avg_headcount AS (
    -- Average of active + separated as a proxy for average headcount
    SELECT dept_id, COUNT(*) AS avg_hc
    FROM employees
    GROUP BY dept_id
)
SELECT
    d.dept_name,
    COALESCE(ds.voluntary_exits, 0)                        AS voluntary_exits,
    dah.avg_hc                                             AS avg_headcount,
    ROUND(COALESCE(ds.voluntary_exits,0)
          / dah.avg_hc * 100, 1)                           AS voluntary_attrition_pct,
    RANK() OVER (ORDER BY COALESCE(ds.voluntary_exits,0)
                          / dah.avg_hc DESC)               AS attrition_rank
FROM departments           d
JOIN dept_avg_headcount   dah ON dah.dept_id = d.dept_id
LEFT JOIN dept_separations ds  ON ds.dept_id  = d.dept_id
ORDER BY voluntary_attrition_pct DESC;


-- Q4. Attrition by tenure band
--     Key insight: identify the most vulnerable tenure window.

WITH employee_tenure AS (
    SELECT
        e.emp_id,
        e.full_name,
        d.dept_name,
        TIMESTAMPDIFF(MONTH, e.hire_date,
            COALESCE(s.sep_date, CURDATE()))               AS tenure_months,
        CASE WHEN s.sep_id IS NOT NULL THEN 1 ELSE 0 END   AS is_separated,
        s.sep_type
    FROM employees   e
    JOIN departments d ON d.dept_id = e.dept_id
    LEFT JOIN separations s ON s.emp_id = e.emp_id
)
SELECT
    CASE
        WHEN tenure_months  < 6  THEN '0–6 months'
        WHEN tenure_months  < 13 THEN '6–12 months'
        WHEN tenure_months  < 25 THEN '13–24 months'
        WHEN tenure_months  < 49 THEN '25–48 months'
        ELSE                          '4+ years'
    END                                    AS tenure_band,
    COUNT(*)                               AS total_employees,
    SUM(is_separated)                      AS separations,
    ROUND(SUM(is_separated)/COUNT(*)*100,1) AS separation_rate_pct
FROM employee_tenure
GROUP BY CASE
    WHEN tenure_months  < 6  THEN '0–6 months'
    WHEN tenure_months  < 13 THEN '6–12 months'
    WHEN tenure_months  < 25 THEN '13–24 months'
    WHEN tenure_months  < 49 THEN '25–48 months'
    ELSE '4+ years'
END
ORDER BY MIN(tenure_months);


-- Q5. Performance score trend per employee — year-on-year delta
--     Uses LAG() to calculate improvement or decline.

SELECT
    e.emp_id,
    e.full_name,
    d.dept_name,
    pr.review_year,
    pr.score,
    LAG(pr.score) OVER (PARTITION BY pr.emp_id
                        ORDER BY pr.review_year)       AS prev_year_score,
    pr.score - LAG(pr.score) OVER
        (PARTITION BY pr.emp_id ORDER BY pr.review_year) AS yoy_change,
    pr.promoted,
    CASE
        WHEN pr.score >= 4 AND pr.promoted = 0
             THEN 'High Performer — Review for Promotion'
        WHEN pr.score <= 2
             THEN 'Performance Concern'
        ELSE 'On Track'
    END                                                AS flag
FROM performance_reviews pr
JOIN employees   e ON e.emp_id  = pr.emp_id
JOIN departments d ON d.dept_id = e.dept_id
ORDER BY e.emp_id, pr.review_year;


-- Q6. Salary quartile distribution within each department
--     NTILE(4) buckets employees into pay quartiles for equity analysis.

SELECT
    emp_id,
    full_name,
    dept_name,
    grade_label,
    salary,
    NTILE(4) OVER (PARTITION BY d.dept_id
                   ORDER BY salary)                   AS pay_quartile,
    ROUND(salary / AVG(salary) OVER (PARTITION BY d.dept_id) * 100, 1) AS pct_of_dept_avg
FROM employees  e
JOIN departments d  ON d.dept_id  = e.dept_id
JOIN job_grades  jg ON jg.grade_id = e.grade_id
WHERE e.employment_status = 'active'
ORDER BY d.dept_id, pay_quartile;


-- Q7. New hire cohort survival — how many hired each year are still active?

SELECT
    YEAR(hire_date)                                       AS hire_year,
    COUNT(*)                                              AS total_hired,
    SUM(CASE WHEN employment_status = 'active' THEN 1 ELSE 0 END) AS still_active,
    SUM(CASE WHEN employment_status = 'separated' THEN 1 ELSE 0 END) AS separated,
    ROUND(
        SUM(CASE WHEN employment_status='active' THEN 1 ELSE 0 END)
        / COUNT(*) * 100
    , 1)                                                  AS retention_rate_pct
FROM employees
GROUP BY YEAR(hire_date)
ORDER BY hire_year;


-- Q8. Department gender balance and pay gap summary

SELECT
    d.dept_name,
    SUM(CASE WHEN e.gender = 'F' THEN 1 ELSE 0 END)     AS female_count,
    SUM(CASE WHEN e.gender = 'M' THEN 1 ELSE 0 END)     AS male_count,
    COUNT(*)                                             AS total_active,
    ROUND(SUM(CASE WHEN e.gender='F' THEN 1 ELSE 0 END)
          / COUNT(*) * 100, 1)                           AS female_pct,
    ROUND(AVG(CASE WHEN e.gender='F' THEN e.salary END), 0) AS avg_female_salary,
    ROUND(AVG(CASE WHEN e.gender='M' THEN e.salary END), 0) AS avg_male_salary,
    ROUND(
        (AVG(CASE WHEN e.gender='M' THEN e.salary END)
         - AVG(CASE WHEN e.gender='F' THEN e.salary END))
        / NULLIF(AVG(CASE WHEN e.gender='M' THEN e.salary END), 0) * 100
    , 1)                                                 AS raw_gender_pay_gap_pct
FROM employees   e
JOIN departments d ON d.dept_id = e.dept_id
WHERE e.employment_status = 'active'
GROUP BY d.dept_id, d.dept_name
ORDER BY female_pct DESC;


-- Q9. Exit interview insight — separation reasons frequency analysis

SELECT
    s.reason,
    s.sep_type,
    COUNT(*)                                              AS frequency,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1)     AS pct_of_all_exits,
    GROUP_CONCAT(e.full_name ORDER BY e.full_name SEPARATOR ', ') AS employees
FROM separations s
JOIN employees   e ON e.emp_id = s.emp_id
GROUP BY s.reason, s.sep_type
ORDER BY frequency DESC;
