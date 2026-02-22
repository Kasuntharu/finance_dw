with transactions as (
    select * from {{ ref('stg_transactions') }}
),

accounts as (
    select * from {{ ref('stg_accounts') }}
),

joined as (
    select
        t.transaction_id,
        t.account_id,
        t.customer_id,
        t.org_id,
        t.transaction_date,
        t.amount,
        t.currency_code,
        a.account_type,
        a.account_category
    from transactions t
    left join accounts a on t.account_id = a.account_id
)

select * from joined
