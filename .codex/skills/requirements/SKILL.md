---
name: requirements
description: Analyze feasibility and produce requirement documents for this repository workflow. Use when a user asks to scope a task, validate implementation viability, clarify acceptance criteria/Definition of Done, or create `workflow/requirements/{task-name}.md` from `.docs/user_story_template.md`.
---

# Requirements

Run the requirements phase from the project workflow (steps 1-4): feasibility, decision, clarification, and requirements authoring.

## Workflow

1. Analyze feasibility against the current repository.
- Inspect architecture, dependencies, and known constraints.
- Confirm whether the request is implementable in the current state.

2. Decide feasibility.
- If not feasible, stop and return:
  - technical reasons
  - concrete blockers
  - viable alternatives
- Do not continue to requirement authoring when not feasible.

3. Clarify before writing.
- Ask objective questions to remove ambiguity.
- Confirm scope boundaries, acceptance criteria, and Definition of Done.
- Record explicit assumptions when information is missing.

4. Create the requirements artifact.
- Read `.docs/user_story_template.md` and follow it exactly.
- Create `workflow/requirements/{task-name}.md`.
- Remove all placeholders from the template.

## Output Contract

Return sections in this order:

1. Feasibility result (`Feasible` or `Not feasible`) with rationale.
2. Clarifications and assumptions.
3. Requirements artifact details:
- file path
- concise content summary

## Quality Checks

- Keep acceptance criteria testable and unambiguous.
- Separate in-scope and out-of-scope explicitly.
- Ensure the document is actionable for the planning phase.
- Never proceed to authoring when feasibility is negative.
