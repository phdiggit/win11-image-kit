# Future True UX Restore State Name Separation Matrix

Status: `state-name-separation-matrix`

This matrix keeps review states readable without allowing one layer to imply another.

## Required Separations

- `handoff-ready-for-human-review` is not `authorization-review-ready`.
- `packet-preview-ready` is not `authorization-review-ready`.
- `approval-checklist-ready` is not `authorization-review-ready`.
- `authorization-review-ready` is not `execute-ready`.
- `execute-ready` is not allowed by the current branch.
- `executed`, `completed`, `issue-18-complete`, and `closure-ready` are forbidden current-branch outcomes.

## Allowed Meaning

- `approval-checklist-ready` means a checklist is readable enough for review.
- `packet-preview-ready` means the integrated packet can be previewed.
- `handoff-ready-for-human-review` means a human reviewer can receive the packet.
- `authorization-review-ready` means the packet can enter authorization review, but still does not approve execution.

## Blocked Promotion Language

The audit blocks wording that says review material "counts as", "is", or "promotes to" true UX evidence, authorization approval, execution approval, or closure readiness.

Forbidden state names may be listed as forbidden examples. They must not appear as an active decision, current readiness, final result, or reviewer instruction.
