#!/usr/bin/env bash
#
# A4I 2026 - Affordable Housing Stability & Eviction Prevention
# Headless fallback for notebooks/c_housing_01_load_explore.ipynb
#
# Rebuilds the same five BigQuery tables the notebook produces, either from a
# pre-staged Cloud Storage snapshot (when A4I_SNAPSHOT_BUCKET is set in .env or
# the environment) or directly from the repo's data/*.parquet files via bq.
#
# Run it from the repo root in Cloud Shell (no chmod needed - invoke with bash):
#     bash scripts/load.sh                 # defaults to san-francisco
#     bash scripts/load.sh chicago
#     bash scripts/load.sh "Baton Rouge"
#     bash scripts/load.sh --list          # show available metros
#
# You still want the notebook if you can run it. Section 2 shows why keyword
# matching fails on habitability complaints, Section 5 exposes the 4x quarterly
# eviction fan-out trap, and Section 6 documents the PII scrubbing judges ask
# about. This script gets you the same tables without the teaching.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TABLES=(
  acs_tract_housing_tenure
  court_eviction_filings
  municipal_311_housing_complaints
  rental_relief_program_bulletins
  municipal_housing_ordinance_statutes
)
REQUIRED=("${TABLES[@]}")
SCOPE_ORDER=(san-francisco chicago new-york austin baton-rouge cincinnati)

declare -A METRO_NAMES=(
  [san-francisco]="San Francisco, CA (state FIPS 06) - the notebook default"
  [chicago]="Chicago, IL (state FIPS 17)"
  [new-york]="New York, NY (state FIPS 36)"
  [austin]="Austin, TX (state FIPS 48)"
  [baton-rouge]="Baton Rouge, LA (state FIPS 22)"
  [cincinnati]="Cincinnati, OH (state FIPS 39)"
)

declare -A METRO_FILTERS=(
  [san-francisco]="San Francisco"
  [chicago]="Chicago"
  [new-york]="New York"
  [austin]="Austin"
  [baton-rouge]="Baton Rouge"
  [cincinnati]="Cincinnati"
)

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
fail() {
  printf '\n\033[1mERROR:\033[0m %s\n\n%s\n\n' "$*" \
    "This script is safe to run again - every table load replaces whatever was there." >&2
  exit 1
}

on_interrupt() {
  printf '\n\n\033[1mInterrupted.\033[0m Nothing is broken.\n'
  printf 'Every load replaces the whole table, so run this script again:\n'
  printf '    bash scripts/load.sh %s\n\n' "${METRO:-<metro>}"
  exit 130
}
trap on_interrupt INT TERM

load_dotenv() {
  local env_file="${REPO_ROOT}/.env" line_no=0 line key val
  [[ -f "${env_file}" ]] || return 0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line_no=$((line_no + 1))
    [[ "${line_no}" -le 200 ]] || fail ".env exceeds 200 lines."
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    if [[ "${line}" =~ ^(A4I_[A-Z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      val="${val%$'\r'}"
      if [[ "${val}" =~ ^\"(.*)\"$ || "${val}" =~ ^\'(.*)\'$ ]]; then
        val="${BASH_REMATCH[1]}"
      fi
      if [[ -z "${!key:-}" ]]; then
        declare -gx "${key}=${val}"
      fi
    fi
  done < "${env_file}"
}

run_timed() {
  [[ $# -ge 1 ]] || fail "Internal error: run_timed called without command."
  [[ "${CMD_TIMEOUT_SEC}" =~ ^[1-9][0-9]{0,3}$ ]] \
    || fail "Invalid A4I_CMD_TIMEOUT_SEC='${CMD_TIMEOUT_SEC}' (expected 1..9999)."
  if command -v timeout >/dev/null 2>&1; then
    timeout "${CMD_TIMEOUT_SEC}s" "$@"
  else
    "$@"
  fi
}

validate_config() {
  SNAPSHOT_BUCKET="${A4I_SNAPSHOT_BUCKET:-}"
  SNAPSHOT_BUCKET="${SNAPSHOT_BUCKET#gs://}"
  SNAPSHOT_BUCKET="${SNAPSHOT_BUCKET%/}"
  SNAPSHOT_PREFIX="${A4I_SNAPSHOT_PREFIX:-a4i-2026/challenge-housing}"
  SNAPSHOT_PREFIX="${SNAPSHOT_PREFIX#/}"
  SNAPSHOT_PREFIX="${SNAPSHOT_PREFIX%/}"
  DATASET="${A4I_DATASET:-a4i_housing}"
  LOCATION="${A4I_LOCATION:-US}"
  CMD_TIMEOUT_SEC="${A4I_CMD_TIMEOUT_SEC:-180}"

  [[ "${CMD_TIMEOUT_SEC}" =~ ^[1-9][0-9]{0,3}$ ]] \
    || fail "Invalid A4I_CMD_TIMEOUT_SEC='${CMD_TIMEOUT_SEC}' (expected 1..9999)."
  [[ "${DATASET}" =~ ^[a-zA-Z_][a-zA-Z0-9_]{0,1023}$ ]] \
    || fail "Invalid dataset identifier '${DATASET}'."
  [[ "${LOCATION}" =~ ^[A-Za-z0-9-]+$ ]] \
    || fail "Invalid BigQuery location '${LOCATION}'."
  if [[ -n "${SNAPSHOT_BUCKET}" ]] && [[ ! "${SNAPSHOT_BUCKET}" =~ ^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$ ]]; then
    fail "Invalid A4I_SNAPSHOT_BUCKET='${SNAPSHOT_BUCKET}'."
  fi
}

list_metros() {
  bold "Metros available for Affordable Housing Stability"
  local found=0 slug label
  if [[ -n "${SNAPSHOT_BUCKET}" ]]; then
    local base_uri="gs://${SNAPSHOT_BUCKET}/${SNAPSHOT_PREFIX}"
    while read -r slug; do
      [[ -z "${slug}" || "${slug}" == "starter" ]] && continue
      found=1
      label="${METRO_NAMES[${slug}]:-(in snapshot bucket)}"
      printf '  %-16s %s\n' "${slug}" "${label}"
    done < <(run_timed gcloud storage ls "${base_uri}/" 2>/dev/null | sed 's|.*/\([^/]*\)/$|\1|')
    [[ "${found}" -eq 1 ]] || fail "Could not list ${base_uri}/. Check network access and authentication."
  else
    for slug in "${SCOPE_ORDER[@]}"; do
      printf '  %-16s %s\n' "${slug}" "${METRO_NAMES[${slug}]}"
    done
  fi
  echo
  echo "Usage: bash scripts/load.sh <metro>"
}

resolve_metro() {
  local raw="${1:-san-francisco}"
  if [[ "${raw}" == "--list" || "${raw}" == "-l" ]]; then
    list_metros
    exit 0
  fi
  if [[ "${raw}" == "--help" || "${raw}" == "-h" ]]; then
    sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
  fi
  [[ "${raw}" != *".."* && "${raw}" != *"/"* ]] \
    || fail "Invalid metro argument '${raw}'."
  METRO="$(printf '%s' "${raw}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//')"
  [[ -n "${METRO}" ]] || fail "Metro argument cannot be empty. Try: bash scripts/load.sh san-francisco"
  METRO_FILTER="${METRO_FILTERS[${METRO}]:-}"
  METRO_LABEL="${METRO_NAMES[${METRO}]:-${METRO}}"
  if [[ -n "${SNAPSHOT_BUCKET}" ]]; then
    SRC="gs://${SNAPSHOT_BUCKET}/${SNAPSHOT_PREFIX}/${METRO}"
  else
    [[ -n "${METRO_FILTER}" ]] || {
      echo
      bold "Unknown metro '${METRO}'."
      echo
      list_metros
      exit 1
    }
    SRC="${REPO_ROOT}/data (filtered to ${METRO_FILTER})"
  fi
}

preflight_checks() {
  bold "A4I Housing Stability - loading data for: ${METRO_LABEL}"
  echo
  command -v bq     >/dev/null 2>&1 || fail "'bq' not found. Run this in Cloud Shell."
  command -v gcloud >/dev/null 2>&1 || fail "'gcloud' not found. Run this in Cloud Shell."

  PROJECT_ID="$(run_timed gcloud config get-value project 2>/dev/null || true)"
  [[ -n "${PROJECT_ID}" && "${PROJECT_ID}" != "(unset)" ]] \
    || fail "No project set. Run: gcloud config set project YOUR_PROJECT_ID"
  [[ "${PROJECT_ID}" =~ ^[a-z][a-z0-9.:-]{4,60}$ ]] \
    || fail "Invalid GCP project ID '${PROJECT_ID}'."

  info "Project : ${PROJECT_ID}"
  info "Metro   : ${METRO}"
  info "Source  : ${SRC}"
  info "Dataset : ${DATASET} (${LOCATION})"
  echo

  if [[ -n "${SNAPSHOT_BUCKET}" ]]; then
    if ! run_timed gcloud storage ls "${SRC}/" >/dev/null 2>&1; then
      echo
      bold "No snapshot found for '${METRO}'."
      echo
      list_metros
      exit 1
    fi
  else
    local tbl
    for tbl in "${REQUIRED[@]}"; do
      [[ -f "${REPO_ROOT}/data/${tbl}.parquet" ]] \
        || fail "Missing ${REPO_ROOT}/data/${tbl}.parquet. Run from the cloned repo root or set A4I_SNAPSHOT_BUCKET."
    done
  fi
}

ensure_dataset() {
  bold "1/3  Creating dataset"
  if run_timed bq --project_id="${PROJECT_ID}" show --dataset --format=none \
       "${PROJECT_ID}:${DATASET}" >/dev/null 2>&1; then
    info "${DATASET} already exists - reusing it"
    local existing_loc
    existing_loc="$(run_timed bq --project_id="${PROJECT_ID}" --format=json show --dataset \
                      "${PROJECT_ID}:${DATASET}" 2>/dev/null \
                    | tr ',' '\n' | grep -i '"location"' | head -1 \
                    | sed 's/.*: *"\([^"]*\)".*/\1/' || true)"
    if [[ -n "${existing_loc}" && "${existing_loc^^}" != "${LOCATION^^}" ]]; then
      fail "Dataset ${DATASET} already exists in '${existing_loc}', but this script loads into
       '${LOCATION}'. BigQuery cannot load across regions, and your Vertex AI embedding
       connection must live in '${LOCATION}' too. Either delete the dataset
       (bq rm -r -d ${DATASET}) or set A4I_LOCATION to match."
    fi
  else
    local mk_out
    if mk_out="$(run_timed bq --project_id="${PROJECT_ID}" --location="${LOCATION}" \
                   mk --dataset "${PROJECT_ID}:${DATASET}" 2>&1)"; then
      info "created ${DATASET}"
    elif grep -qi "already exists" <<<"${mk_out}"; then
      info "${DATASET} already exists - reusing it"
    else
      fail "Could not create dataset ${DATASET}: ${mk_out}"
    fi
  fi
  echo
}

build_311_scrub_sql() {
  local fq_dest="$1" fq_raw="$2"
  cat <<SQL
CREATE OR REPLACE TABLE ${fq_dest} AS
SELECT * REPLACE (
  LPAD(census_tract_geoid, 11, '0') AS census_tract_geoid,
  REGEXP_REPLACE(
    REPLACE(
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(
              REGEXP_REPLACE(
                REPLACE(complaint_narrative, CHR(65533), CHR(39)),
                r'(?i)\b(my\s+name\s+is\s+|property\s+manager,?\s+)[A-Z][A-Za-z\x27\-]+(?:\s+[A-Z][A-Za-z\x27\-]+){0,2}',
                '\\\\1[REDACTED NAME]'
              ),
              r'(?i)(license\s+plate\s*#?\s*)[A-Z0-9\-]+',
              '\\\\1[REDACTED PLATE]'
            ),
            r'(?i)\b(dwelling\s+unit|apt\.?|apartment|room|rm\.?|suite|ste\.?)\s*[:#]?\s*\d+[A-Za-z]?(?:\s*(?:,|and)\s*\d+[A-Za-z]?)*',
            '\\\\1 [REDACTED UNIT]'
          ),
          r'(?i)\b(\d{2,5})\s+Block\b',
          '\\\\1__A4I_BLOCK__'
        ),
        r'(?i)\b(\d{2,5})(?:\s*[/\-]\s*\d{2,5})?\s+([A-Za-z0-9.\-]+(?:\s+[A-Za-z0-9.\-]+){0,2}\s+(?:St|Street|Ave|Avenue|Blvd|Boulevard|Rd|Road|Dr|Drive|Ln|Lane|Ct|Court|Way|Pl|Place)\b)',
        '[REDACTED STREET NUMBER] \\\\2'
      ),
      '__A4I_BLOCK__',
      ' Block'
    ),
    r'(?i)(service\s+address:\s*)\d{2,5}\b',
    '\\\\1[REDACTED STREET NUMBER]'
  ) AS complaint_narrative
)
FROM ${fq_raw}
WHERE metro_area = '${METRO_FILTER}'
SQL
}

build_local_filter_sql() {
  local table="$1"
  local fq_dest="\`${PROJECT_ID}.${DATASET}.${table}\`"
  local fq_raw="\`${PROJECT_ID}.${DATASET}._raw_${table}\`"
  case "${table}" in
    acs_tract_housing_tenure)
      printf 'CREATE OR REPLACE TABLE %s AS SELECT * REPLACE (LPAD(census_tract_geoid, 11, '\''0'\'') AS census_tract_geoid, LPAD(county_fips, 5, '\''0'\'') AS county_fips) FROM %s WHERE metro_area = '\''%s'\''' \
        "${fq_dest}" "${fq_raw}" "${METRO_FILTER}"
      ;;
    court_eviction_filings)
      printf 'CREATE OR REPLACE TABLE %s AS SELECT * REPLACE (LPAD(census_tract_geoid, 11, '\''0'\'') AS census_tract_geoid) FROM %s WHERE metro_area = '\''%s'\''' \
        "${fq_dest}" "${fq_raw}" "${METRO_FILTER}"
      ;;
    municipal_311_housing_complaints)
      build_311_scrub_sql "${fq_dest}" "${fq_raw}"
      ;;
    *)
      printf 'CREATE OR REPLACE TABLE %s AS SELECT * FROM %s WHERE metro_area = '\''%s'\''' \
        "${fq_dest}" "${fq_raw}" "${METRO_FILTER}"
      ;;
  esac
}

load_all_tables() {
  bold "2/3  Loading tables"
  local table uri sql
  for table in "${TABLES[@]}"; do
    info "loading ${table}..."
    if [[ -n "${SNAPSHOT_BUCKET}" ]]; then
      uri="${SRC}/${table}/data.parquet"
      if ! run_timed gcloud storage ls "${uri}" >/dev/null 2>&1; then
        uri="${SRC}/${table}/*.parquet"
        run_timed gcloud storage ls "${SRC}/${table}/" >/dev/null 2>&1 \
          || fail "Missing ${SRC}/${table}/. The snapshot for '${METRO}' looks incomplete - tell a coach."
      fi
      run_timed bq --project_id="${PROJECT_ID}" --location="${LOCATION}" load \
        --source_format=PARQUET --replace "${DATASET}.${table}" "${uri}" >/dev/null
    else
      run_timed bq --project_id="${PROJECT_ID}" --location="${LOCATION}" load \
        --source_format=PARQUET --replace \
        "${DATASET}._raw_${table}" "${REPO_ROOT}/data/${table}.parquet" >/dev/null
      sql="$(build_local_filter_sql "${table}")"
      run_timed bq --project_id="${PROJECT_ID}" --location="${LOCATION}" query \
        --use_legacy_sql=false --format=none "${sql}" >/dev/null
      run_timed bq --project_id="${PROJECT_ID}" rm -f -t \
        "${PROJECT_ID}:${DATASET}._raw_${table}" >/dev/null
    fi
    info "  done"
  done
  echo
}

verify_tables() {
  bold "3/3  Verifying"
  FAILED=0
  local table rows
  for table in "${TABLES[@]}"; do
    rows="$(run_timed bq --project_id="${PROJECT_ID}" --location="${LOCATION}" \
              query --use_legacy_sql=false --format=csv \
              "SELECT COUNT(*) FROM \`${PROJECT_ID}.${DATASET}.${table}\`" \
            | tail -n 1)"
    if [[ "${rows}" == "0" ]]; then
      printf '  %-38s %s\n' "${table}" "0 rows  <-- EMPTY"
      FAILED=1
    else
      printf '  %-38s %s rows\n' "${table}" "${rows}"
    fi
  done
  echo
}

verify_challenge_signals() {
  bold "Does this metro support the challenge?"
  local tracts filings open_res decoys hab_bul variety
  read -r tracts filings open_res decoys hab_bul variety <<<"$(
    run_timed bq --project_id="${PROJECT_ID}" --location="${LOCATION}" \
      query --use_legacy_sql=false --format=csv \
      "SELECT
         (SELECT COUNT(*) FROM \`${PROJECT_ID}.${DATASET}.acs_tract_housing_tenure\`),
         (SELECT COUNT(*) FROM \`${PROJECT_ID}.${DATASET}.court_eviction_filings\`),
         (SELECT IFNULL(COUNTIF(NOT STARTS_WITH(request_id, 'DECOY-')
                                AND STARTS_WITH(inspection_status, 'Open')
                                AND property_type = 'Residential'), 0)
            FROM \`${PROJECT_ID}.${DATASET}.municipal_311_housing_complaints\`),
         (SELECT IFNULL(COUNTIF(STARTS_WITH(request_id, 'DECOY-')), 0)
            FROM \`${PROJECT_ID}.${DATASET}.municipal_311_housing_complaints\`),
         (SELECT IFNULL(COUNTIF(requires_open_habitability_case), 0)
            FROM \`${PROJECT_ID}.${DATASET}.rental_relief_program_bulletins\`),
         (SELECT IFNULL(ROUND(100.0 * COUNT(DISTINCT complaint_narrative) / NULLIF(COUNT(*), 0), 1), 0)
            FROM \`${PROJECT_ID}.${DATASET}.municipal_311_housing_complaints\`)" \
    | tail -n 1 | tr ',' ' '
  )"

  printf '  %-46s %s\n' "census tracts"                                  "${tracts}"
  printf '  %-46s %s\n' "quarterly eviction rows (4 quarters/tract)"     "${filings}"
  printf '  %-46s %s\n' "open real residential 311 complaints"           "${open_res}"
  printf '  %-46s %s\n' "planted decoy 311 cases (3+3+3 eligibility)"    "${decoys}"
  printf '  %-46s %s\n' "relief bulletins requiring open habitability"   "${hab_bul}"
  printf '  %-46s %s%%\n' "distinct 311 complaint narratives"            "${variety}"
  echo

  if [[ "${open_res}" == "0" ]]; then
    info "  <-- ZERO open residential 311 cases. Habitability triage cannot run here."
    FAILED=1
  elif [[ "${open_res}" -lt 25 ]]; then
    info "  NOTE: ${METRO_LABEL} has ${open_res} open residential 311 requests and $((165 - open_res))"
    info "  closed historical ones. That is a real source-mix finding (and tests your"
    info "  closed_date IS NULL filter), not a broken load."
    echo
  fi

  if [[ "${FAILED}" -eq 1 ]]; then
    fail "One or more required tables loaded empty or lacked open cases. Tell a coach."
  fi
}

print_ready_footer() {
  bold "Ready."
  echo
  echo "  Your tables are in ${PROJECT_ID}.${DATASET}"
  echo "  Safe to re-run at any time - each load replaces the whole table."
  echo
  echo "  THREE TRAPS THAT COST TEAMS CREDIT IF SKIPPED:"
  echo "    1. court_eviction_filings has 4 quarters per tract - pre-aggregate by"
  echo "       census_tract_geoid before joining to 311 complaints or rows inflate 4x."
  echo "    2. 9 DECOY-* cases in municipal_311_housing_complaints look urgent in text"
  echo "       but fail Commercial or Closed-case eligibility rules."
  echo "    3. Never pass audit_* demographic columns into scoring/retrieval; reserve"
  echo "       them strictly for your post-output Equity Audit."
  echo
  echo "  Next: embed complaint_narrative + raw_bulletin_text with AI.EMBED and run"
  echo "  VECTOR_SEARCH. See Section 13 of notebooks/c_housing_01_load_explore.ipynb."
  echo
}

load_dotenv
validate_config
resolve_metro "${1:-san-francisco}"
preflight_checks
ensure_dataset
load_all_tables
verify_tables
verify_challenge_signals
print_ready_footer
