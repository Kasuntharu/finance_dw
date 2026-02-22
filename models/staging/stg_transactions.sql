with source as (
    select * from {{ ref('raw_transactions') }}
),

renamed as (
    select
        transaction_id,
        account_id,
        customer_id,
        org_id,
        transaction_date,
        cast(amount as decimal(18,2)) as amount,
        currency as currency_code,
        description,
        created_at
    from source
)

select * from renamed
