# data/

Pre-staged GeoParquet starter tables covering all six metros (`San Francisco`, `Chicago`, `New York`, `Austin`, `Baton Rouge`, and `Cincinnati`). When `A4I_SNAPSHOT_BUCKET` is unset, both [`notebooks/c_housing_01_load_explore.ipynb`](../notebooks/c_housing_01_load_explore.ipynb) and [`scripts/load.sh`](../scripts/load.sh) filter and load your chosen metro directly from these five files into `a4i_housing` inside your Google Cloud project.

**Read the `data_provenance` column in every table.** You should not trust generated or modeled data you cannot inspect, and neither should a judge.

## Files in this folder

### `acs_tract_housing_tenure.parquet` (378 rows across 6 metros)

- **Provenance:** **Real public data.** US Census Bureau American Community Survey (ACS) 5-Year estimates (`B25070` Gross Rent as a Percentage of Household Income and `B19013` Median Household Income) joined with TIGER/Line census tract polygons (`tract_geom`).
- **License:** US Government Work (public domain under 17 U.S.C. 105).
- **Important rule:** Carries five `audit_*` demographic share columns (`audit_black_share`, `audit_hispanic_share`, `audit_asian_share`, `audit_indigenous_share`, `audit_white_share`). Never pass these into scoring, retrieval, or LLM prompts. Reserve them strictly for your post-output Equity Audit.

### `court_eviction_filings.parquet` (1,512 rows, 4 quarters per tract)

- **Provenance:** **Modeled from public baselines.** Simulated quarterly tract eviction filings calibrated to county civil-court aggregates and ACS severe rent burden. Princeton's Eviction Lab has zero California coverage and only ZIP-level New York City coverage, so tract-level quarterly counts here are modeled rather than court-scraped.
- **License:** Original modeled dataset authored for Agents for Impact 2026 (Apache 2.0).
- **Grain trap:** Contains **four quarters per census tract** (`reporting_quarter`). Always aggregate by `census_tract_geoid` before joining to 311 complaints, or your complaint counts will inflate 4x.

### `municipal_311_housing_complaints.parquet` (1,044 rows: 174 per metro)

- **Provenance:** **990 real public 311/code-enforcement rows + 54 labeled `[Planted Case]` decoys (9 per metro).** Real rows come from official municipal open-data portals (`data.sfgov.org`, NYC Open Data, Chicago Data Portal, `data.austintexas.gov`, `data.brla.gov`, and Cincinnati Open Data), redacted to the 100-block (`block_address`) and pre-scrubbed on disk of residual citizen names, apartment numbers, exact street house numbers, and license plates (with idempotent regex scrubbing re-applied during load).
- **Planted decoys (`DECOY-*`):** Nine synthetic rows per metro (`Example Teaching Way [Planted Case]`) test whether your pipeline filters out commercial properties (`3`), closed/abated cases (`3`), and no-violation inspections (`3`) after running `VECTOR_SEARCH`.

### `rental_relief_program_bulletins.parquet` (24 rows: 4 per metro)

- **Provenance:** **Public policy text.** Summarized local emergency rental assistance and habitability stabilization guidelines, including structured boolean flags (`requires_open_habitability_case`, `residential_tenants_only`) paired with unstructured `raw_bulletin_text`.

### `municipal_housing_ordinance_statutes.parquet` (18 rows: 3 per metro)

- **Provenance:** **Public statutory text.** State and municipal implied-warranty-of-habitability, rent-escrow, and anti-retaliation code citations (`code_citation`, `raw_statute_text`).
