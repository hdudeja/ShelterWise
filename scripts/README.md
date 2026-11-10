# scripts/

Headless alternatives to the notebook, for when a Colab Enterprise runtime is slow or
unavailable.

`load.sh` reaches the same end state as `notebooks/c_housing_01_load_explore.ipynb`—the same five
tables, with native `GEOGRAPHY` columns (`tract_geom`, `property_geom`), leading-zero-safe 11-digit
tract GEOIDs, and scrubbed 311 narratives, in `a4i_housing` inside your project. Use the notebook
if you can: it takes two to three minutes, demonstrates why keyword search fails in Section 2, and
walks through the 4× eviction fan-out trap and PII scrubbing that judges ask about. Use this script
if you cannot.

## Running it

From the **root of the repo**, in Cloud Shell:

```bash
bash scripts/load.sh                   # loads San Francisco, CA—the default
bash scripts/load.sh chicago           # Chicago, IL
bash scripts/load.sh "Baton Rouge"     # Baton Rouge, LA
bash scripts/load.sh --list            # show every pre-staged metro
bash scripts/load.sh --help            # usage
```

Invoke it with `bash` rather than `./scripts/load.sh` so it works regardless of whether the file's
executable bit survived how your copy of the repository was created.

By default, if `A4I_SNAPSHOT_BUCKET` is configured in `.env` (or exported in your shell; see
`.env.example`), `load.sh` loads pre-filtered GeoParquet snapshots from Cloud Storage. If
`A4I_SNAPSHOT_BUCKET` is unset, it loads and filters directly from the repository's
`data/*.parquet` files using `bq`.

## It is safe to run more than once

Every table is fully replaced (`--replace`), never appended to. Canceling halfway through or
switching metros on a second run overwrites the previous metro's tables cleanly rather than mixing
cities.

## What the verification block checks

After verifying non-zero row counts across all five tables, `load.sh` queries your loaded BigQuery
tables for the signals your agent depends on:

- **4× quarterly eviction structure (`court_eviction_filings`)**: four quarters per tract—remind
  every teammate to aggregate by `census_tract_geoid` before joining to 311 cases.
- **Open residential 311 mix**: Baton Rouge legitimately carries `10` open real residential 311
  cases alongside `155` closed historical cases despite the pack's highest severe rent burden; the
  script flags this as a finding rather than failing.
- **9 planted `DECOY-*` cases (`3` Commercial open + `3` Closed - Abated + `3` Closed - No
  Violation)**: verifies the eligibility-trap test cases are intact for your `VECTOR_SEARCH` +
  structured eligibility filter.
