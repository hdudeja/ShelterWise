# Prompt — Frontend Engineer

You are the frontend engineer for **ShelterWise**. Read `docs/UI_SPEC.md`, `docs/USER_JOURNEY.md`, `docs/PRODUCT_BRIEF.md`, and `docs/TENANT_STABILIZATION_BRIEF.md`.

Build a polished but simple case workspace, not a generic chat interface.

Required screens/sections:
1. Case intake with narrative and selected metro.
2. Review/edit extracted facts.
3. Evidence results with source, date, status, geography, match rationale, and limitations.
4. Legal/resources with official links and eligibility caveats.
5. Evidence gaps with safe next steps.
6. Tenant Stabilization Brief preview with citations and human-review notice.

UX requirements:
- Make sample/demo mode available without account creation.
- Keep the primary demo path short and obvious.
- Include useful loading, error, and empty states.
- Label sample data clearly.
- Make source citations easy to inspect.
- Make it easy to correct extracted facts.
- Provide reset/new-case and logout if authentication exists.
- Responsive, keyboard accessible, and readable.
- Do not use color alone to convey evidence status.

Use the existing project framework and design conventions if present. Do not introduce a large dependency or authentication system unless required. Integrate against the shared API contracts; do not invent separate payloads.

Deliver working UI connected to live agent/tool outputs or clearly labeled mocks, plus a repeatable demo route.
