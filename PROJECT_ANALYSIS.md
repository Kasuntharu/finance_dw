# Finance Data Warehouse — Project Analysis

A **dbt (data build tool)** project that builds a finance data warehouse with a **Medallion architecture** (Bronze → Silver → Gold), star-style analytics in Gold, SCD Type 2 via snapshots in Silver, and **DuckDB** as the target.

---

## 1. Project overview

| Property | Value |
|----------|--------|
| **Name** | `finance_dw` |
| **Version** | 1.0.0 |
| **Profile** | `finance_dw` |
| **Target** | DuckDB (`finance.duckdb`, 4 threads) |
| **Config version** | 2 |

**Paths:**

- **Models** → `models/`
- **Seeds** → `seeds/`
- **Snapshots** → `snapshots/`
- **Tests** → `tests/`
- **Macros** → `macros/`
- **Analyses** → `analyses/`

**Dependencies:** `dbt-labs/dbt_utils` v1.1.1 (used for `date_spine` and `expression_is_true`).

---

## 2. Medallion architecture (DuckDB)

The project is aligned with **Medallion**: Bronze (raw) → Silver (clean + historical + reusable) → Gold (analytics). Schemas keep responsibilities clear and support scalability and governance.

| Medallion layer | dbt mapping | DuckDB schema | Purpose |
|-----------------|-------------|---------------|---------|
| **Bronze (Raw)** | Sources (+ seeds) | `raw` | Source-aligned data; minimal transformation; append-only, auditable. |
| **Silver** | Snapshots | `snapshots` | SCD2 history for accounts and customers. |
| **Silver** | Staging + Intermediate | `silver` | Renaming, casting, standardisation; reusable joins and shared logic. |
| **Gold** | Marts | `gold` | Facts and dimensions for BI and reporting; clear grain and contracts. |

**Data flow:**

```
Bronze (raw)           Silver                           Gold
─────────────────      ─────────────────────────        ─────────────────────
Sources / Seeds        Snapshots (SCD2)                  Marts
  raw.raw_*     →        snapshots.*              →     gold.dim_*
       ↓                    ↓                            gold.fct_*
       └──────────────────→ silver.stg_* (views)
                                    ↓
                            silver.int_* (ephemeral)
                                    ↓
                            gold.dim_* / gold.fct_*
```

**Design choices:**

- **Bronze = dbt Sources** — Raw data lives in schema `raw` (ingestion or `dbt seed`). No transformation; preserve what the source gives.
- **Snapshots in Silver** — SCD2 for customers and accounts lives in schema `snapshots`; staging then consumes these for consistent, historical-aware Silver models.
- **Silver = Snapshots + Staging + Intermediate** — One place for history and cleaning; Gold stays lean and stable.
- **Gold = Marts** — Facts and dimensions with enforced contracts; this is what BI and reporting consume.

Schema naming is controlled by `macros/generate_schema_name.sql` so layer schemas are exactly `raw`, `snapshots`, `silver`, and `gold` in all environments.

---

## 3. Architecture (layer summary)

| Layer | Schema | Materialization | Purpose |
|-------|--------|-----------------|---------|
| **Staging** | silver | View | Clean, rename, cast; single source of truth per entity. |
| **Intermediate** | silver | Ephemeral | Enrich transactions with account metadata (no persisted table). |
| **Marts** | gold | Table | Star-style dimensions and fact table for reporting. |

---

## 4. Sources and seeds (Bronze / raw)

### 4.1 Source definition (`models/staging/sources.yml`)

- **Source:** `finance_source`, schema **`raw`** (Bronze)
- **Tables:** `raw_customers`, `raw_accounts`, `raw_transactions`, `raw_organizations`

Raw data lives in schema `raw`. It can be loaded by an ingestion job or populated via `dbt seed` (seeds are configured with `+schema: raw`).

### 4.2 Seeds (CSV)

| Seed file | Role |
|-----------|------|
| `raw_customers.csv` | Customer master (customer_id, customer_name, customer_type, region, updated_at) |
| `raw_accounts.csv` | Chart of accounts (account_id, account_code, account_name, account_type, account_category, updated_at) |
| `raw_transactions.csv` | Ledger transactions (transaction_id, account_id, customer_id, org_id, transaction_date, amount, currency, description, created_at) |
| `raw_organizations.csv` | Orgs/cost centres (org_id, cost_center_code, cost_center_name, entity_name) |

Snapshots use `ref('raw_accounts')` and `ref('raw_customers')`, which resolve to the seed tables in schema `raw` when seeds are loaded.

---

## 5. Snapshots (Silver — SCD Type 2)

| Snapshot | Unique key | Strategy | Source |
|----------|------------|----------|--------|
| `accounts_snapshot` | `account_id` | `timestamp` on `updated_at` | `ref('raw_accounts')` |
| `customers_snapshot` | `customer_id` | `timestamp` on `updated_at` | `ref('raw_customers')` |

- **Target:** schema **`snapshots`** (Silver / historical layer).
- **Purpose:** Track history of account and customer attributes; staging and Gold marts consume from these snapshots.

---

## 6. Staging models (Silver — views)

| Model | Source | Description |
|-------|--------|-------------|
| `stg_organizations` | `finance_source.raw_organizations` | Orgs/cost centres, renamed columns |
| `stg_transactions` | `finance_source.raw_transactions` | Transactions; `amount` cast to `decimal(18,2)`, `currency` → `currency_code` |
| `stg_accounts` | `accounts_snapshot` | Account versions; exposes `dbt_valid_from` / `dbt_valid_to` as `valid_from` / `valid_to` |
| `stg_customers` | `customers_snapshot` | Customer versions; same validity columns as accounts |

Staging lives in schema **`silver`** and enforces not-null, unique, accepted values, and relationships (e.g. `stg_transactions` → `stg_accounts`, `stg_customers`, `stg_organizations`). Amount is tested non-zero via `dbt_utils.expression_is_true`.

---

## 7. Intermediate models (Silver — ephemeral)

| Model | Description |
|-------|-------------|
| `int_transactions_enriched` | `stg_transactions` left-joined to `stg_accounts`; adds `account_type` and `account_category` per transaction. One row per transaction. Used as logical input for the fact table and other marts. |

Ephemeral models are inlined into downstream SQL and not materialized as their own table/view. They are part of the Silver layer (schema `silver`).

---

## 8. Marts (Gold — tables)

### 7.1 Dimensions

| Model | Type | Source | Key columns |
|-------|------|--------|-------------|
| `dim_customers` | SCD2 | `stg_customers` | customer_id, current_name, customer_type, region, valid_from, valid_to, **is_current** |
| `dim_accounts` | SCD2 | `stg_accounts` | account_id, account_code, account_name, account_type, account_category, valid_from, valid_to, **is_active** |
| `dim_organizations` | Static | `stg_organizations` | org_id, cost_center_code, cost_center_name, entity_name |
| `dim_dates` | Generated | `dbt_utils.date_spine` | full_date, year, quarter, month, day, year_month (2023-01-01 → 2025-01-01) |

### 7.2 Fact table

| Model | Description |
|-------|-------------|
| `fct_ledger_entries` | One row per transaction: transaction_id, account_id, customer_id, org_id, transaction_date, amount, currency_code, description, created_at. Built from `stg_transactions` (not from `int_transactions_enriched` in the current SQL). |

All mart models live in schema **`gold`** and use **contract enforcement** (`contract.enforced: true`) so breaking changes cause build failures.

---

## 9. Tests

### 9.1 Schema/column tests (in `schema.yml` files)

- **Uniqueness / not null** on keys and critical attributes.
- **Accepted values** for enums (e.g. customer_type, region, account_type, account_category).
- **relationships** from fact and staging to dimensions/staging (referential integrity).
- **dbt_utils.expression_is_true** for `amount != 0` on `stg_transactions`.

### 9.2 Singular tests (SQL in `tests/`)

| Test file | Purpose |
|-----------|---------|
| `assert_no_orphan_transactions.sql` | Rows in `fct_ledger_entries` with no matching `dim_accounts.account_id` (LEFT JOIN anti-pattern). Passes when 0 rows returned. |
| `assert_transaction_amount_not_zero.sql` | Rows in `fct_ledger_entries` where `amount IS NULL` or `amount = 0`. Passes when 0 rows returned. |

---

## 10. File structure

```
finance_dw/
├── dbt_project.yml          # Medallion: seeds→raw, staging/intermediate→silver, marts→gold
├── profiles.yml              # finance_dw → DuckDB (finance.duckdb)
├── packages.yml              # dbt_utils 1.1.1
├── macros/
│   └── generate_schema_name.sql   # Layer schemas: raw, silver, gold (no env prefix)
├── models/
│   ├── staging/
│   │   ├── sources.yml      # finance_source → schema raw (Bronze)
│   │   ├── schema.yml
│   │   ├── stg_organizations.sql
│   │   ├── stg_transactions.sql
│   │   ├── stg_accounts.sql
│   │   └── stg_customers.sql
│   ├── intermediate/
│   │   ├── schema.yml
│   │   └── int_transactions_enriched.sql
│   └── marts/
│       ├── schema.yml       # Gold contracts + tests
│       ├── dim_customers.sql
│       ├── dim_accounts.sql
│       ├── dim_organizations.sql
│       ├── dim_dates.sql
│       └── fct_ledger_entries.sql
├── snapshots/                # Silver — history (schema: snapshots)
│   ├── accounts_snapshot.sql
│   └── customers_snapshot.sql
├── seeds/                    # Loaded into schema raw (Bronze)
│   ├── raw_customers.csv
│   ├── raw_accounts.csv
│   ├── raw_transactions.csv
│   └── raw_organizations.csv
└── tests/
    ├── assert_no_orphan_transactions.sql
    └── assert_transaction_amount_not_zero.sql
```

---

## 11. How to run

1. **Install dbt and adapter:**  
   e.g. `pip install dbt-duckdb` (or use a supported DuckDB setup).

2. **Load seeds (if using CSV as raw):**  
   `dbt seed`

3. **Run snapshots:**  
   `dbt snapshot`

4. **Build models:**  
   `dbt run`

5. **Run tests:**  
   `dbt test`

6. **Generate docs:**  
   `dbt docs generate` then `dbt docs serve`

---

## 12. Design notes

- **Referential integrity:** Staging and marts enforce FKs to dimensions; singular test guards against orphan transactions in the fact table.
- **Zero amounts:** Disallowed in staging (expression test) and in the fact table (singular test + contract).
- **SCD2:** Customers and accounts are versioned via snapshots; dimensions expose `valid_from`, `valid_to`, and a current-version flag (`is_current` / `is_active`).
- **Contracts:** Marts use enforced contracts so schema and type changes are caught at build time.
- **int_transactions_enriched:** Provides account_type/account_category for analytics; the current `fct_ledger_entries` is built directly from `stg_transactions`. To expose account attributes in the fact layer, `fct_ledger_entries` could be switched to select from `int_transactions_enriched` and add those columns.
- **Medallion:** Snapshots are part of Silver (historical layer); they feed staging, so history is captured before Gold. Gold stays lean and stable.

---

## 13. Summary

| Aspect | Detail |
|--------|--------|
| **Stack** | dbt + DuckDB |
| **Architecture** | Medallion: Bronze (raw) → Silver (snapshots + staging + intermediate) → Gold (marts) |
| **Schemas** | `raw` (ingestion), `snapshots` (history), `silver` (transformations), `gold` (analytics) |
| **SCD2** | Customers and accounts via dbt snapshots in Silver |
| **Quality** | Schema tests, relationships, singular tests for orphans and zero amounts |
| **Interface** | Gold marts with enforced contracts for BI/reporting |

This document reflects the project as of the current codebase. For the latest lineage and column details, run `dbt docs generate` and open the dbt docs UI.
