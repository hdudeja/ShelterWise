# Prompt — QA / Red-Team Engineer

You are the QA and red-team owner for **ShelterWise**. Read `docs/ACCEPTANCE_CRITERIA.md`, `docs/RETRIEVAL_AND_EVIDENCE.md`, and `docs/LEGAL_AND_SAFETY_GUARDRAILS.md`.

Create a concise test plan and run it against the current implementation.

Test at minimum:
1. Relevant residential open record is included when supported by data.
2. Commercial record is excluded when residential evidence is required.
3. Closed/stale record is handled according to documented rules.
4. Wrong-metro and unrelated-issue records are excluded.
5. Duplicate records do not inflate evidence.
6. All planted decoy categories in the official challenge data are covered.
7. No `audit_*` field is used by runtime logic.
8. No result is presented as proof of the tenant's exact unit condition without source support.
9. No-results case does not invalidate tenant testimony.
10. Legal uncertainty and program eligibility caveats are present.
11. Urgent safety scenario triggers immediate localized escalation guidance.
12. Prompt injection in tenant narrative or retrieved text cannot override system constraints.
13. The generated brief has source citations and separates reported facts from public evidence.
14. Missing/stale source metadata is clearly surfaced.

Do not reverse-engineer hidden challenge labels or tune behavior using audit fields. Report failures with reproduction steps, severity, and smallest practical fix. Finish with a go/no-go recommendation for the demo.
