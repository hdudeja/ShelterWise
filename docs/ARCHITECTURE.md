# Architecture

## Proposed high-level design

```text
Tenant / Advocate
       |
       v
ShelterWise Case Workspace (web UI)
       |
       v
Google ADK Orchestrator + Gemini
       |
       +--> Intake & Fact Structuring
       |
       +--> Evidence Retrieval Tool ----> BigQuery structured records
       |                                  BigQuery vector search
       |                                  public 311 / housing datasets
       |
       +--> Legal & Resource Lookup ----> curated jurisdiction sources
       |
       +--> Evidence Gap Planner
       |
       +--> Brief Generator
       |
       v
Tenant Stabilization Brief + Human Review
```

## Design choice: one orchestrator

Use one ADK orchestrating agent with focused, deterministic tools. Avoid a swarm of autonomous agents for the MVP. Tool outputs should be typed, bounded, and source-backed.

## Suggested tool contracts

### `structure_intake`
Input: tenant narrative and optional structured answers.
Output: normalized issue categories, dates, location scope, reported facts, urgency flags, unknowns, and clarification questions.
Rule: preserve original narrative; never silently convert an inference into a fact.

### `search_public_evidence`
Input: metro, geographic scope, issue categories, time window, filters.
Output: candidate records, source IDs, dates, status, geography, matched fields, exclusion reasons, and caveats.
Rule: hard filters first; semantic similarity only assists discovery/ranking among eligible candidates.

### `lookup_legal_resources`
Input: jurisdiction, issue categories, notice/deadline context.
Output: official source excerpts/links, applicability notes, eligibility conditions, effective dates, and reviewer warnings.
Rule: retrieval does not equal legal determination.

### `identify_evidence_gaps`
Input: reported facts, found evidence, and desired brief fields.
Output: missing information, why it matters, and safe next-step suggestions.
Rule: no public record found must never be framed as proof that the event did not occur.

### `generate_stabilization_brief`
Input: verified intake facts, evidence results, legal/resource references, gaps.
Output: structured brief matching `TENANT_STABILIZATION_BRIEF.md`.
Rule: cite every external factual claim; label user-reported facts; include human-review notice.

## Data and infrastructure

- **Google ADK + Gemini:** orchestration, extraction, explanation, and drafting.
- **MCP:** controlled access to approved tools/data sources where required by challenge.
- **BigQuery:** structured public data, normalized tables, vector embeddings/search.
- **Cloud Run / approved agent runtime:** deployment target; verify challenge-specific requirement.
- **Frontend:** lightweight responsive case workspace; keep the demo path short.

## Vector retrieval pattern

1. Normalize and validate the query.
2. Apply mandatory structured filters (metro/jurisdiction, residential relevance, date/status, issue category).
3. Run vector search over eligible records or use vector results as candidate generation followed by hard validation.
4. Deduplicate and rank with transparent features.
5. Return source metadata and match rationale.
6. Never infer unit-level conditions from neighborhood-level records.

## Reliability and observability

Log tool name, latency, query filters, result counts, and error class. Do not log raw sensitive tenant narratives by default. Track citation coverage, decoy rejection, stale-source rate, and unsupported-claim rate.
