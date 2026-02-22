-- =============================================================================
-- assert_no_orphan_transactions.sql
--
-- THEORY: Singular test — returns the violating rows.
-- dbt passes this test when this query returns ZERO rows.
--
-- PURPOSE:
--   Foreign key integrity check at the mart level.
--   A transaction that references an account_id which does NOT exist in
--   dim_accounts is called an "orphan". Orphan records indicate:
--     1. A referential integrity failure in the source system
--     2. A join logic bug in the staging or intermediate layers
--     3. An account that was deleted from the dimension without cascading
--
--   In financial reporting, orphan transactions produce unmapped ledger entries
--   that silently distort account-level aggregations (P&L, balance sheet, etc.).
--
-- WHAT IS CHECKED:
--   Transactions in fct_ledger_entries whose account_id has no matching
--   record in dim_accounts (LEFT JOIN anti-pattern).
--
-- NOTE: A similar pattern could be added for customer_id → dim_customers
--       and org_id → dim_organizations if needed.
-- =============================================================================

select
    f.transaction_id,
    f.account_id,
    f.customer_id,
    f.org_id,
    f.amount,
    f.transaction_date
from {{ ref('fct_ledger_entries') }} f
left join {{ ref('dim_accounts') }} da
    on f.account_id = da.account_id
where da.account_id is null
