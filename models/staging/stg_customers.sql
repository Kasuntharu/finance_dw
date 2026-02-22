with source as (
    select * from {{ ref('customers_snapshot') }}
),

renamed as (
    select
        customer_id,
        customer_name,
        customer_type,
        region,
        updated_at,
        dbt_valid_from as valid_from,
        dbt_valid_to as valid_to
    from source
)

select * from renamed
