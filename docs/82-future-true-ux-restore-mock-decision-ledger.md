# Future True UX Restore Mock Decision Ledger

Status: `mock-decision-ledger`

Refs #18

## Ledger

| Stage | Decision | Reason | Allowed next state | Forbidden next state | Evidence source | Execution flags |
|---|---|---|---|---|---|---|
| `received` | `accepted-for-mock-review` | fixture packet exists | `packet-complete` | `execute-ready` | mock request fixture | `AuthorizationApproved=false; ExecutionApproved=false; ExecuteReady=false; trueExecution=false; mutationCount=0` |
| `packet-complete` | `complete` | required packet fields are present | `authorization-review-ready` | `executed` | mock evidence packet | `AuthorizationApproved=false; ExecutionApproved=false; ExecuteReady=false; trueExecution=false; mutationCount=0` |
| `authorization-review-ready` | `ready-for-review-only` | reviewer checklist passes | `not-execute-ready` | `completed` | mock transcript | `AuthorizationApproved=false; ExecutionApproved=false; ExecuteReady=false; trueExecution=false; mutationCount=0` |
| `execute-ready-blocked` | `blocked` | execution approval is outside this drill | `true-execution-blocked` | `execute-ready` | mock decision ledger | `AuthorizationApproved=false; ExecutionApproved=false; ExecuteReady=false; trueExecution=false; mutationCount=0` |
| `true-execution-blocked` | `blocked` | no mutation is authorized | `blocked-for-execution` | `executed` | mock decision ledger | `AuthorizationApproved=false; ExecutionApproved=false; ExecuteReady=false; trueExecution=false; mutationCount=0` |

## Summary

The ledger proves only that the review workflow can run on a complete mock packet. It does not prove user configuration restoration, does not approve execution, and does not change mutation flags.
