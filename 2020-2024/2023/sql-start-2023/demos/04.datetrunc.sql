------------------------------------------------------------------------
-- GREATEST/LEAST
------------------------------------------------------------------------
DECLARE @d datetime2 = '2021-12-08 11:30:15.1234567';
SELECT	'Original' AS date_part, @d AS truncated_date
UNION ALL
SELECT 'Year' AS date_part, DATETRUNC(year, @d) AS truncated_date
UNION ALL
SELECT 'Quarter' AS date_part, DATETRUNC(quarter, @d) AS truncated_date
UNION ALL
SELECT 'Month' AS date_part, DATETRUNC(month, @d) AS truncated_date
UNION ALL
SELECT 'Week' AS date_part, DATETRUNC(week, @d) AS truncated_date -- Using the default DATEFIRST setting value of 7 (U.S. English)
UNION ALL
SELECT 'Iso_week' AS date_part, DATETRUNC(iso_week, @d) AS truncated_date
UNION ALL
SELECT 'DayOfYear' AS date_part, DATETRUNC(dayofyear, @d) AS truncated_date
UNION ALL
SELECT 'Day' AS date_part, DATETRUNC(day, @d) AS truncated_date
UNION ALL
SELECT 'Hour' AS date_part, DATETRUNC(hour, @d) AS truncated_date
UNION ALL
SELECT 'Minute' AS date_part, DATETRUNC(minute, @d) AS truncated_date
UNION ALL
SELECT 'Second' AS date_part, DATETRUNC(second, @d) AS truncated_date
UNION ALL
SELECT 'Millisecond' AS date_part, DATETRUNC(millisecond, @d) AS truncated_date
UNION ALL
SELECT 'Microsecond' AS date_part, DATETRUNC(microsecond, @d) AS truncated_date