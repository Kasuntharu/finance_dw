with transactions as (
    select * from {{ ref('stg_transactions') }}
),

dates as (
    select full_date, year_month from {{ ref('dim_dates') }}
),

joined as (
    select
        t.transaction_id,
        t.account_id,
        t.customer_id,
        t.org_id,
        t.transaction_date,
        d.year_month as transaction_year_month,
        t.amount,
        t.currency_code,
        t.description,
        t.created_at
    from transactions t
    left join dates d on t.transaction_date = d.full_date
)

select
    transaction_id,
    account_id,
    customer_id,
    org_id,
    transaction_date,
    transaction_year_month,
    amount,
    currency_code,
    description,
    created_at
from joined
