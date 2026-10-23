# Local pipeline (no cloud account needed): synthetic GA4 sample -> dbt on DuckDB -> findings report
# Production: the same dbt models on the real GA4 public dataset in BigQuery (make bigquery)
PY ?= python
export DUCKDB_PATH := $(CURDIR)/data/warehouse.duckdb
export GA4_SAMPLE_PATH := $(CURDIR)/data/ga4_sample
export DBT_SEND_ANONYMOUS_USAGE_STATS := false

.PHONY: setup lint test sample dbt bq-syntax report all bigquery bigquery-report clean

setup:
	$(PY) -m pip install -r requirements.txt

lint:
	ruff check .

test:
	$(PY) -m pytest -q

sample:
	$(PY) scripts/generate_sample_data.py --out data/ga4_sample --users 4000 --seed 42

dbt:
	cd dbt && dbt build --profiles-dir . --target local

# BigQuery version of every model, compiled and parsed offline (no Google account needed)
bq-syntax:
	cd dbt && rm -rf target_bq && dbt compile --profiles-dir . --target local --vars '{render_bigquery_sql: true}' --target-path target_bq -q
	$(PY) scripts/check_bigquery_sql.py dbt/target_bq/compiled

report:
	$(PY) -m analysis.report --target local --out data/findings_local.md

all: lint test sample dbt bq-syntax report

# Real data (needs GCP_PROJECT_ID and Application Default Credentials)
bigquery:
	cd dbt && dbt build --profiles-dir . --target bigquery

bigquery-report:
	$(PY) -m analysis.report --target bigquery --out docs/findings.md

clean:
	rm -rf data dbt/target dbt/target_bq dbt/logs
