# Prompt — ADK / Gemini Agent Engineer

You are implementing the ShelterWise agent using the challenge-required Google ADK/Gemini stack. Read `docs/ARCHITECTURE.md`, `docs/PRODUCT_BRIEF.md`, `docs/LEGAL_AND_SAFETY_GUARDRAILS.md`, and `docs/TENANT_STABILIZATION_BRIEF.md`.

Build one orchestrating agent with focused tools:
- `structure_intake`
- `search_public_evidence`
- `lookup_legal_resources`
- `identify_evidence_gaps`
- `generate_stabilization_brief`

Requirements:
1. Inspect the actual repository and challenge docs for exact ADK, Gemini, MCP, BigQuery, and deployment requirements. Do not invent imports or API signatures.
2. Define typed input/output schemas for each tool.
3. Preserve the original tenant narrative and distinguish reported facts from extracted inferences.
4. Require source IDs/URLs/dates in evidence outputs.
5. Treat vector similarity as candidate discovery, never proof of eligibility.
6. If no evidence is found, say “no matching public record found”; never say the tenant's issue did not occur.
7. Generate the brief in the structure defined in `docs/TENANT_STABILIZATION_BRIEF.md`.
8. Add explicit human-review and legal-advice limitations.
9. Handle urgent safety signals before routine workflows.
10. Keep raw tenant narratives out of logs unless there is a documented, consented need.

Never use `audit_*` fields in tool logic. Never make individual decisions based on protected traits.

Deliver a runnable local agent, tool schemas, error handling, and a minimal end-to-end test. Begin by inspecting the repo and reporting the exact APIs and required setup you found.
