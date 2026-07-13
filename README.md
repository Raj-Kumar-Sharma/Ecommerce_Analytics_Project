# 📊 E-Commerce Intelligence Platform

An end-to-end, enterprise-grade analytics platform for e-commerce transactional data — from synthetic data generation through ETL cleaning, SQL warehousing, and a modern interactive Streamlit dashboard.

> **v2.0** — Full architectural rebuild of the original single-script prototype into a modular, tested, production-ready application.

---

## ✨ Features

- **Modern, dark enterprise dashboard** (Streamlit + Plotly) with 5 pages: Executive Snapshot, Sales Overview, Customer Insights, Product Analytics, and Cohort Retention
- **Interactive filters**: date-range picker, top-N sliders, live KPI cards
- **Reusable analytics core** (`src/analytics/`) shared by the dashboard and the CLI — one source of truth for every SQL query
- **Pluggable warehouse backend**: SQLite out of the box, or Snowflake for enterprise deployments — toggled with a single environment variable
- **Synthetic data generator** that intentionally injects real-world messiness (invalid emails, malformed dates, orphaned records, negative quantities) so the cleaning pipeline has real problems to solve
- **CLI reporting engine** with data-integrity audits and executive summaries
- **Pytest suite** covering generation, cleaning, and query correctness
- **Config-driven** via `.env` — no hardcoded paths or credentials

---

## 🏗️ Architecture & Workflow

```
 ┌────────────────────┐     ┌──────────────────────┐     ┌───────────────────────┐
 │  1. Data Generation │ --> │  2. ETL / Cleaning    │ --> │  3. SQL Warehouse     │
 │  generate_data.py   │     │  clean_data.py         │     │  SQLite / Snowflake    │
 │  (synthetic, messy) │     │  (validate + load)     │     │  (schema.sql)          │
 └────────────────────┘     └──────────────────────┘     └───────────┬───────────┘
                                                                       │
                                             ┌─────────────────────────┼─────────────────────────┐
                                             ▼                                                    ▼
                                 ┌───────────────────────┐                          ┌───────────────────────┐
                                 │ 4a. Streamlit Dashboard│                          │ 4b. CLI Reporting Tool │
                                 │  dashboard/Home.py     │                          │  report_cli.py         │
                                 └───────────────────────┘                          └───────────────────────┘
```

Both the dashboard and the CLI import their queries from **`src/analytics/queries.py`** and **`src/analytics/report.py`**, so business logic (e.g. the revenue formula, which order statuses are excluded) is defined exactly once.

**Revenue formula** (used consistently everywhere):
```
revenue = quantity × unit_price × (1 − discount_percent / 100)
```

---

## 📁 Project Structure

```
ecommerce-analytics-system/
             #

├── scripts/                     
│   ├── generate_data.py
│   ├── clean_data.py
│   └── report_cli.py
├── sql/                         # Reference SQL (DDL + analytical query library)
│   ├── schema.sql
│   ├── aggregations.sql
│   ├── window_functions.sql
│   └── cohort_analysis.sql
├    
├── data/{raw,cleaned}/          
├── output/sample_reports/
├── Project_report.pdf  
├── README.md
```

---

## 🚀 Installation & Setup

**Requirements:** Python 3.10+

```bash
# 1. Clone / unzip the project, then from the project root:
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. (Optional) configure environment
cp .env.example .env             # defaults work out of the box with SQLite
```

---

## ▶️ Execution

Run these **from the project root**, in order:

```bash
# Step 1 — generate synthetic raw data (data/raw/*.csv)
python scripts/generate_data.py

# Step 2 — clean + load into the SQL warehouse (data/ecommerce_warehouse.db)
python scripts/clean_data.py

# Step 3a — launch the interactive dashboard
streamlit run dashboard/Home.py

# Step 3b — or generate a CLI executive report instead
python scripts/report_cli.py --report monthly --start 2024-01-01 --end 2026-12-31 --save
```



---


---

## 🧪 Testing
```

The suite generates data and runs the full pipeline in an isolated temp directory (no impact on real `data/`), then verifies:
- correct row counts are produced (regression test for a data-generation bug in the original script)
- all known anomalies (invalid emails, orphaned rows, zero-quantity items) are removed
- every dashboard query executes and returns valid results

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| Dashboard | Streamlit, Plotly |
| Data processing | Pandas |
| Warehouse | SQLite (default) / Snowflake (optional) |
| Synthetic data | Faker |
| Config | python-dotenv |
| Testing | Pytest |

---


---

# 👨‍💻 Author

**Raj kumar**

B.Tech in Computer Science (Artificial Intelligence & Data Science)

Poornima University, Jaipur

GitHub Portfolio Project

---
