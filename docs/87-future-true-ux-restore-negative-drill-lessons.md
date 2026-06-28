# Future True UX Restore Negative Drill Lessons

Status: `negative-drill-lessons`

The negative drill makes these review rules explicit:

1. Maintainer approval is a separate gate from packet completeness.
2. Scope must stay singular and consistent across request, packet, and scope guard assertion.
3. Command exit code success is not user-visible UX restore evidence.
4. Dry-run reports, handler reports, manual checklists, mock transcripts, and CI status are not true restore evidence.
5. Packet metadata must match the reviewed artifact and decision ledger.
6. Rollback or restore explanation must exist before a packet can progress.
7. High-risk mutation vocabulary in a report-only path keeps the request blocked.

This lesson set is deliberately not execute-ready. It supports future review discipline while preserving the current report-only Issue #18 boundary.
