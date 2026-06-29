# Future True UX Restore Negative Review Transcript

Status: `negative-review-transcript`

The generated transcript records why a negative case cannot advance. It is intentionally review-only and avoids any execute-ready language.

Transcript fields:

- `summary`: names the negative case and confirms it remains review-only.
- `decision`: one of `blocked`, `needs-rework`, or `rejected`.
- `findings`: reason-code lines from the validator.
- `warning`: states that dry-run, handler, manual, mock, and CI artifacts are not true UX restore evidence.
- `executionBoundary`: states that no restore command, installer, registry, profile, AppX, service, DISM, Defender, Junction, Start menu, taskbar, Sysprep, or network action is allowed.

The transcript is useful for maintainers because it separates review feedback from execution approval. A passing negative drill only proves the blocker was detected.
