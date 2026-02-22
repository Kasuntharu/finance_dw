-- =============================================================================
-- assert_transaction_amount_not_zero.sql
--
-- THEORY: Singular test — returns the violating rows.
-- dbt passes this test when this query returns ZERO rows.
--
-- PURPOSE:
--   In financial double-entry bookkeeping, a transaction with amount = 0
--   is meaningless — it creates a ledger entry that neither increases nor
--   decreases any account balance. This is almost always a data pipeline bug
--   (e.g., a NULL cast to 0, or a miscalculated running total).
--
-- WHAT IS CHECKED:
--   • amount IS NULL        → the not_null constraint was bypassed
--   • amount = 0            → zero-value entries violate business rules
-- =============================================================================

select
    transaction_id,
    account_id,
    customer_id,
    amount,
    transaction_date,
    currency_code
from {{ ref('fct_ledger_entries') }}
where
    amount is null
    or amount = 0
