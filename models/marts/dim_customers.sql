select
    customer_id,
    customer_name as current_name,
    customer_type,
    region,
    valid_from,
    valid_to,
    case when valid_to is null then true else false end as is_current
from {{ ref('stg_customers') }}
