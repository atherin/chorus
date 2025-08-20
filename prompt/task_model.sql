DROP TABLE IF EXISTS dim_person CASCADE;
CREATE TABLE dim_person (
    person_key BIGSERIAL PRIMARY KEY,
    person_id VARCHAR(50) NOT NULL,          -- natural key
    name VARCHAR(200) NOT NULL,
    effective_dt DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_dt DATE,
    current_flag SMALLINT NOT NULL DEFAULT 1
);

COMMENT ON COLUMN dim_person.person_key IS 'Surrogate primary key for person dimension';
COMMENT ON COLUMN dim_person.person_id IS 'Natural/business key for person (e.g., username or external ID)';
COMMENT ON COLUMN dim_person.name IS 'Full name of the person';
COMMENT ON COLUMN dim_person.effective_dt IS 'Date when the person record becomes effective';
COMMENT ON COLUMN dim_person.expiry_dt IS 'Date when the person record expires (if applicable)';
COMMENT ON COLUMN dim_person.current_flag IS 'Flag indicating if the record is the current version (1=current, 0=historical)';

DROP TYPE IF EXISTS task_cadence CASCADE;
CREATE TYPE task_cadence AS ENUM ('daily', 'weekly', 'monthly');
DROP TABLE IF EXISTS dim_task CASCADE;
CREATE TABLE dim_task (
    task_key BIGSERIAL PRIMARY KEY,
    task_id VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    cadence task_cadence,
    max_occurrences INT,
    effective_dt DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_dt DATE,
    current_flag SMALLINT NOT NULL DEFAULT 1
);
COMMENT ON COLUMN dim_task.task_key IS 'Surrogate primary key for task dimension';
COMMENT ON COLUMN dim_task.task_id IS 'Natural/business key for task';
COMMENT ON COLUMN dim_task.title IS 'Title or name of the task';
COMMENT ON COLUMN dim_task.description IS 'Detailed description of the task';
COMMENT ON COLUMN dim_task.cadence IS 'Cadence/frequency of the task (e.g., daily, weekly, monthly)';
COMMENT ON COLUMN dim_task.max_occurrences IS 'Maximum number of times the task can occur in the cadence period';
COMMENT ON COLUMN dim_task.effective_dt IS 'Date when the task record becomes effective';
COMMENT ON COLUMN dim_task.expiry_dt IS 'Date when the task record expires (if applicable)';
COMMENT ON COLUMN dim_task.current_flag IS 'Flag indicating if the record is the current version (1=current, 0=historical)';

DROP TABLE IF EXISTS dim_date CASCADE;
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,                -- YYYYMMDD surrogate
    full_dt DATE NOT NULL,
    day_of_week INT,
    day_name VARCHAR(20),
    week_of_year INT,
    month INT,
    month_name VARCHAR(20),
    quarter INT,
    year INT,
    is_weekend SMALLINT
);
COMMENT ON COLUMN dim_date.date_key IS 'Surrogate key representing the date in YYYYMMDD format';
COMMENT ON COLUMN dim_date.full_dt IS 'Full calendar date';
COMMENT ON COLUMN dim_date.day_of_week IS 'Day of week as integer (0=Sunday, 6=Saturday)';
COMMENT ON COLUMN dim_date.day_name IS 'Name of the day (e.g., Monday)';
COMMENT ON COLUMN dim_date.week_of_year IS 'Week number within the year';
COMMENT ON COLUMN dim_date.month IS 'Month as integer (1-12)';
COMMENT ON COLUMN dim_date.month_name IS 'Name of the month (e.g., January)';
COMMENT ON COLUMN dim_date.quarter IS 'Quarter of the year (1-4)';
COMMENT ON COLUMN dim_date.year IS 'Year (e.g., 2024)';
COMMENT ON COLUMN dim_date.is_weekend IS 'True if the date falls on a weekend (Saturday or Sunday)';

DROP TYPE IF EXISTS task_status CASCADE;
CREATE TYPE task_status AS ENUM ('Not Started', 'In Progress', 'Completed');
DROP TABLE IF EXISTS fact_occurrence CASCADE;
CREATE TABLE fact_occurrence (
    fact_occurrence_key BIGSERIAL PRIMARY KEY,
    task_key BIGINT NOT NULL REFERENCES dim_task(task_key),
    person_key BIGINT NOT NULL REFERENCES dim_person(person_key),
    date_key INT NOT NULL REFERENCES dim_date(date_key),
    status_name task_status NOT NULL,
    completed_dt_key INT REFERENCES dim_date(date_key),
    insert_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_ts TIMESTAMP
);
COMMENT ON COLUMN fact_occurrence.fact_occurrence_key IS 'Surrogate primary key for fact_occurrence';
COMMENT ON COLUMN fact_occurrence.task_key IS 'Foreign key referencing dim_task (task performed)';
COMMENT ON COLUMN fact_occurrence.person_key IS 'Foreign key referencing dim_person (who performed the task)';
COMMENT ON COLUMN fact_occurrence.date_key IS 'Foreign key referencing dim_date (date of occurrence)';
COMMENT ON COLUMN fact_occurrence.status_name IS 'Current status of the task occurrence';
COMMENT ON COLUMN fact_occurrence.completed_dt_key IS 'Foreign key referencing dim_date (when the task was completed, if applicable)';
COMMENT ON COLUMN fact_occurrence.insert_ts IS 'Timestamp when the record was inserted';
COMMENT ON COLUMN fact_occurrence.update_ts IS 'Timestamp when the record was last updated';

INSERT INTO dim_person (person_id, name)
VALUES 
('ricardo', 'Ricardo'),
('shanaya', 'Shanaya'),
('daniel', 'Daniel');

INSERT INTO dim_task (task_id, title, cadence, max_occurrences, description)
VALUES
('task1', 'Task 1', 'monthly', 12, 'Monthly recurring task'),
('task2', 'Task 2', null, 1, 'One-time task'),
('task3', 'Task 3', 'daily', 30, 'Daily recurring task');

INSERT INTO dim_date (date_key, full_dt, day_of_week, day_name, week_of_year, month, month_name, quarter, year, is_weekend)
SELECT
    TO_NUMBER(TO_CHAR(d, 'YYYYMMDD'), '99999999')::INT AS date_key,
    d AS full_dt,
    EXTRACT(DOW FROM d)::INT AS day_of_week,
    TO_CHAR(d, 'Day') AS day_name,
    EXTRACT(WEEK FROM d)::INT AS week_of_year,
    EXTRACT(MONTH FROM d)::INT AS month,
    TO_CHAR(d, 'Month') AS month_name,
    EXTRACT(QUARTER FROM d)::INT AS quarter,
    EXTRACT(YEAR FROM d)::INT AS year,
    CASE WHEN EXTRACT(DOW FROM d) IN (0,6) THEN 1 ELSE 0 END AS is_weekend
FROM generate_series('1900-01-01'::date, '2200-12-31'::date, '1 day') AS d;

ALTER TABLE fact_occurrence
    ADD CONSTRAINT fk_fact_occurrence__task
        FOREIGN KEY (task_key)
        REFERENCES dim_task(task_key);

ALTER TABLE fact_occurrence
    ADD CONSTRAINT fk_fact_occurrence__person
        FOREIGN KEY (person_key)
        REFERENCES dim_person(person_key);

ALTER TABLE fact_occurrence
    ADD CONSTRAINT fk_fact_occurrence__date
        FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key);

ALTER TABLE fact_occurrence
    ADD CONSTRAINT fk_fact_occurrence__completed_date
        FOREIGN KEY (completed_dt_key)
        REFERENCES dim_date(date_key);

CREATE INDEX idx_fact_task_dt ON fact_occurrence(task_key, date_key);
CREATE INDEX idx_fact_person_dt ON fact_occurrence(person_key, date_key);
CREATE INDEX idx_fact_task_person ON fact_occurrence(task_key, person_key);
CREATE INDEX idx_fact_status ON fact_occurrence(status_name);
CREATE INDEX idx_fact_completed_date ON fact_occurrence(completed_dt_key);