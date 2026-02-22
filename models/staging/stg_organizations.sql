with source as (
    select * from {{ ref('raw_organizations') }}
),

renamed as (
    select
        org_id,
        cost_center_code,
        cost_center_name,
        entity_name
    from source
)

select * from renamed
