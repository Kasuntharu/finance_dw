# finance_dw

A **financial data warehouse** built with **dbt** and **DuckDB**, aligned with **Medallion architecture** (Bronze → Silver → Gold). Includes raw seeds, SCD Type 2 snapshots, staging and intermediate models, and Gold marts (dimensions + fact) with enforced contracts and tests.

---

## Prerequisites

- **Python 3.8+**
- **DuckDB CLI** (for the local UI; optional but useful for inspecting the database)

---

## 1. Install DuckDB CLI (optional, for UI)

### macOS (Homebrew)

```bash
brew install duckdb
```

### Linux

**Option A — Official install script (recommended):**

```bash
curl -fsSL https://install.duckdb.org | bash
# Adds DuckDB to ~/.duckdb/cli; ensure that directory is on your PATH
export PATH="$HOME/.duckdb/cli:$PATH"
```

**Option B — Package manager (if available):**

```bash
# e.g. on Debian/Ubuntu (check for your distro)
sudo apt-get update && sudo apt-get install -y duckdb
```

---

## 2. Clone and enter the project

```bash
git clone git@github.com:Kasuntharu/finance_dw.git
cd finance_dw
```

---

## 3. Create and activate a virtual environment

Create a venv named `.dbt_env` in the project root and activate it:

**macOS / Linux:**

```bash
python3 -m venv .dbt_env
source .dbt_env/bin/activate
```

**Windows (PowerShell):**

```powershell
python -m venv .dbt_env
.dbt_env\Scripts\Activate.ps1
```

You should see `(.dbt_env)` in your prompt.

---

## 4. Install Python dependencies

```bash
pip install -r requirements.txt
```

This installs `dbt-core`, `dbt-duckdb`, and `duckdb` (for Python/scripts).

---

## 5. Install dbt packages

```bash
dbt deps
```

This pulls in the project’s dbt packages (e.g. `dbt_utils`) defined in `packages.yml`.

---

## 6. Load raw data (seeds)

```bash
dbt seed
```

Loads the CSV seeds into the **raw** schema (Bronze). Creates/updates `raw_customers`, `raw_accounts`, `raw_transactions`, `raw_organizations`. The DuckDB file `finance.duckdb` is created in the project root if it doesn’t exist.

---

## 7. Run snapshots (SCD Type 2)

```bash
dbt snapshot
```

Builds SCD Type 2 history for customers and accounts in the **snapshots** schema (Silver).

---

## 8. Build models

```bash
dbt run
```

Runs all models in order: Silver (staging views, intermediate) and Gold (dimensions and fact table). Use `dbt run --full-refresh` if you need to rebuild tables from scratch.

---

## 9. Run tests (recommended)

```bash
dbt test
```

Runs schema tests (uniqueness, not null, relationships, accepted values, etc.) and singular tests (e.g. no orphan transactions, no zero amounts).

---

## 10. Open the DuckDB UI (inspect data)

With the DuckDB CLI installed and `finance.duckdb` created (after `dbt seed` / `dbt run`):

```bash
duckdb -ui finance.duckdb
```

This starts the local DuckDB web UI and opens `finance.duckdb`. You can browse schemas (`raw`, `snapshots`, `silver`, `gold`), run SQL, and explore tables.

**Alternative (from inside DuckDB CLI):**

```bash
duckdb finance.duckdb
```

Then in the DuckDB prompt:

```sql
CALL start_ui();
```

---

## Quick reference: full run order

```bash
python3 -m venv .dbt_env
source .dbt_env/bin/activate    # or .dbt_env\Scripts\Activate.ps1 on Windows
pip install -r requirements.txt
dbt deps
dbt seed
dbt snapshot
dbt run
dbt test
duckdb -ui finance.duckdb      # optional: open UI
```

---

## Optional: dbt docs

Generate and serve the dbt docs (lineage, model descriptions, tests):

```bash
dbt docs generate
dbt docs serve
```

Then open the URL shown in the terminal (usually http://localhost:8080).

---

## Project layout (Medallion)

| Layer   | Schema(s)   | Contents |
|--------|-------------|----------|
| Bronze | `raw`       | Seeds / source tables |
| Silver | `snapshots` | SCD2 snapshots (customers, accounts) |
| Silver | `silver`    | Staging views, intermediate logic |
| Gold   | `gold`      | Dimensions (`dim_*`) and fact (`fct_ledger_entries`) |

For a full description of the project, architecture, and lineage, see **[PROJECT_ANALYSIS.md](PROJECT_ANALYSIS.md)**.

---

## License

See repository settings or add a LICENSE file as needed.
