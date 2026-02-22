with date_spine as (
  {{ dbt_utils.date_spine(
      datepart="day",
      start_date="cast('2023-01-01' as date)",
      end_date="cast('2025-01-01' as date)"
     )
  }}
)

select
    date_day as full_date,
    extract(year from date_day) as year,
    extract(quarter from date_day) as quarter,
    extract(month from date_day) as month,
    extract(day from date_day) as day,
    strftime(date_day, '%Y-%m') as year_month
from date_spine
