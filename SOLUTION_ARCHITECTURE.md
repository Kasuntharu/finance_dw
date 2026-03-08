# Finance DW — Solution Architecture

High-level architecture for the financial data warehouse: Medallion layers (Bronze → Silver → Gold) implemented with **dbt** and **DuckDB**.

---

## Diagram (Mermaid)

The diagram below renders on GitHub and in any Markdown viewer that supports Mermaid.

```mermaid
flowchart TB
    subgraph Input["📥 Input"]
        CSV[("CSV Seeds\n(raw_*.csv)")]
    end

    subgraph Orchestration["⚙️ Orchestration"]
        dbt["dbt\n(seed · snapshot · run · test)"]
    end

    subgraph Store["💾 DuckDB (finance.duckdb)"]
        subgraph Bronze["🥉 Bronze · schema: raw"]
            raw_cust[raw_customers]
            raw_acct[raw_accounts]
            raw_org[raw_organizations]
            raw_txn[raw_transactions]
        end

        subgraph SilverSnap["🥈 Silver · schema: snapshots"]
            snap_cust[customers_snapshot\nSCD Type 2]
            snap_acct[accounts_snapshot\nSCD Type 2]
        end

        subgraph SilverStg["🥈 Silver · schema: silver"]
            stg_cust[stg_customers]
            stg_acct[stg_accounts]
            stg_org[stg_organizations]
            stg_txn[stg_transactions]
            int_txn[int_transactions_enriched]
        end

        subgraph Gold["🥇 Gold · schema: gold"]
            dim_dates[dim_dates]
            dim_cust[dim_customers]
            dim_acct[dim_accounts]
            dim_org[dim_organizations]
            fct[fct_ledger_entries]
        end
    end

    subgraph Quality["✅ Data Quality"]
        tests["Schema tests\nSingular tests\n(orphans, zero amount)"]
    end

    subgraph Consume["📊 Consumption"]
        BI["BI / Reporting\n(consume Gold only)"]
    end

    CSV --> dbt
    dbt --> Bronze
    Bronze --> SilverSnap
    Bronze --> SilverStg
    SilverSnap --> SilverStg
    SilverStg --> Gold
    Gold --> tests
    Gold --> BI
```

---

## Simplified flow (one page)

```mermaid
flowchart LR
    subgraph Bronze["🥉 Bronze"]
        A[("raw\n(seeds)")]
    end

    subgraph Silver["🥈 Silver"]
        B[snapshots\nSCD2]
        C[staging\n+ intermediate]
    end

    subgraph Gold["🥇 Gold"]
        D[dim_*]
        E[fct_ledger_entries]
    end

    A --> B
    A --> C
    B --> C
    C --> D
    C --> E
    D --> E
    E --> F[Tests & BI]
```

---

## Component summary

| Component | Role |
|-----------|------|
| **CSV seeds** | Source-aligned raw data loaded via `dbt seed` into schema `raw`. |
| **dbt** | Orchestrates seed, snapshots, model DAG, and tests. |
| **DuckDB** | Single-file database; schemas `raw`, `snapshots`, `silver`, `gold`. |
| **Bronze (raw)** | Immutable copy of source; minimal or no transformation. |
| **Silver (snapshots)** | SCD Type 2 history for customers and accounts. |
| **Silver (staging + int)** | Cleans, renames, casts; reusable joins (e.g. transactions enriched). |
| **Gold** | Star-style dimensions and fact table; enforced contracts. |
| **Tests** | Schema tests + singular tests (referential integrity, business rules). |
| **BI / Reporting** | Consume Gold only for analytics. |

---

For run order and setup, see [README.md](README.md). For detailed lineage and design, see [PROJECT_ANALYSIS.md](PROJECT_ANALYSIS.md).
