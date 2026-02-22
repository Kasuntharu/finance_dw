select
    account_id,
    account_code,
    account_name,
    account_type,
    account_category,
    valid_from,
    valid_to,
    case when valid_to is null then true else false end as is_active
from {{ ref('stg_accounts') }}
