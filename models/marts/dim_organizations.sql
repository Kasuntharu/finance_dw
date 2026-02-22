select
    org_id,
    cost_center_code,
    cost_center_name,
    entity_name
from {{ ref('stg_organizations') }}
