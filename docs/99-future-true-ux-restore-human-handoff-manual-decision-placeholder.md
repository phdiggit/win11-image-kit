# Future True UX Restore Human Handoff Manual Decision Placeholder

Status: `human-authorization-handoff-manual-decision-placeholder`

The manual decision placeholder reserves a place for a maintainer decision without pre-filling authorization or execution approval.

Allowed handoff decisions:

- `handoff-ready-for-human-review`
- `needs-rework`
- `blocked`

Forbidden handoff decisions:

- `authorization-review-ready`
- `execute-ready`
- `executed`
- `completed`
- `issue-18-complete`
- `closure-ready`

The placeholder should say that a human maintainer may review the packet, request rework, or block it. It must not say that the maintainer approved execution.
