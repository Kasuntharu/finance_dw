with source as (
    select * from {{ ref('accounts_snapshot') }}
),

renamed as (
    select
        account_id,
        account_code,
        account_name,
        account_type,
        account_category,
        updated_at,
        dbt_valid_from as valid_from,
        dbt_valid_to as valid_to
    from source
)

select * from renamed
