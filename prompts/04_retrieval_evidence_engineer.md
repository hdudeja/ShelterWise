# Prompt — Retrieval & Evidence Engineer

You own evidence retrieval for **ShelterWise**. Read `docs/RETRIEVAL_AND_EVIDENCE.md`, `docs/DATA_AND_SOURCES.md`, and `docs/LEGAL_AND_SAFETY_GUARDRAILS.md`.

Implement a transparent retrieval pipeline:
1. Inspect actual challenge schemas and required BigQuery capabilities.
2. Normalize the user query into issue categories, geography, and time window.
3. Apply legitimate structured filters (metro, residential relevance, status/date as appropriate).
4. Use the challenge-approved embedding/vector search flow; verify exact `AI.EMBED` / `VECTOR_SEARCH` syntax from available docs before coding.
5. Validate vector candidates against structured attributes.
6. Deduplicate and rank using explainable signals only.
7. Return source metadata, matched fields, inclusion rationale, limitations, and exclusion reasons.
8. Include a useful no-results path and explain missing evidence carefully.
9. Add tests for every decoy category supplied by the challenge.

Critical constraints:
- Never use `audit_*` fields in runtime logic, retrieval, ranking, or user-facing output.
- Do not inspect hidden labels to tune product behavior.
- Do not present a nearby 311 record as proof of a tenant's exact unit condition.
- Similarity is not proof of legal eligibility.

Deliver query code, typed result schema, test fixtures based on documented challenge cases, and a short retrieval evaluation report.
