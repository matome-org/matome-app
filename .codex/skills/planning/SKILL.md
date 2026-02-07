---
name: planning
description: Build implementation plans from approved requirements in this repository workflow. Use when a user asks to create `workflow/plans/{task-name}.md` from `workflow/requirements/{task-name}.md` using `.docs/plan_template.md`, including testing strategy, impact analysis, and regression-risk mitigation.
---

# Planning

Run workflow planning step 7: produce an execution-ready plan file traceable to requirements.

## Workflow

1. Load planning inputs.
- Read `workflow/requirements/{task-name}.md` as source of truth.
- Read `.docs/plan_template.md` and preserve its structure.

2. Map requirements to plan sections.
- Convert each acceptance criterion into planned work.
- Ensure coverage across architecture, tasks, and deliverables.

3. Author complete plan artifact.
- Create `workflow/plans/{task-name}.md`.
- Remove all placeholders from the template.
- Include mandatory elements:
  - implementation phases
  - task breakdown
  - deliverables per phase
  - testing strategy (automated and/or manual)
  - impact analysis on existing features
  - regression risks and mitigation
  - dependencies and assumptions

4. Verify traceability before finalizing.
- Confirm every requirement is mapped to at least one task and one validation path.
- Confirm risks include concrete mitigation actions.

## Output Contract

Return sections in this order:

1. Plan artifact path.
2. Traceability matrix summary (`requirement -> planned task/test`).
3. Top risks and mitigation summary.

## Quality Checks

- Keep the plan actionable without extra interpretation.
- Keep test strategy explicit for new and impacted behavior.
- Keep risk analysis concrete and implementation-oriented.
- Never leave template placeholders unresolved.
