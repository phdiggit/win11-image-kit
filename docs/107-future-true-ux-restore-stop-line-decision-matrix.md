# Future True UX Restore Stop-Line Decision Matrix

Status: `stop-line-decision-matrix`

This matrix describes what a maintainer can decide after reading the final stop-line handoff. It keeps all current branch decisions outside execution.

| Decision | Meaning | Allowed next step |
|---|---|---|
| `pause-at-stop-line` | The current preparation chain is complete enough to stop. | Do not add more review-only layers. |
| `request-rework` | A preparation artifact is missing or inconsistent. | Return to the specific missing artifact and repair it. |
| `start-true-restore-planning` | A human explicitly wants a real restore planning chain. | Open a new issue or task chain with a fresh Runner Gate. |
| `close-issue-manually` | The maintainer manually closes Issue #18 outside PR automation. | Manual maintainer action only; no PR auto-close wording. |

## Forbidden Outputs

The current branch must not output `execute-ready`, `executed`, `completed`, `issue-18-complete`, or `closure-ready`. These words are listed here only as forbidden outputs.

The PR body must use `Refs #18` only. It must not use the three GitHub auto-close forms for Issue #18.

## Evidence Boundary

Review-only artifacts cannot become true UX restore evidence. If true restore planning begins later, it must define fresh evidence requirements, fresh safety review, and a new Runner Gate before any implementation work.
