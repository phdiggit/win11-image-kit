# Future True UX Restore Mock Review Packet Drill

Status: `mock-review-drill`

Refs #18

## Scope

This document defines a single-scope mock authorization review drill for `current-user`. The drill uses fixture-only request and evidence packet data. It is not a real authorization grant and does not restore real user experience settings.

## Packet

The drill packet contains:

- one scope: `current-user`
- a redacted target identity
- a dry-run command envelope
- before evidence placeholder
- after evidence placeholder
- rollback plan
- independent verification placeholder
- failure propagation statement
- maintainer review checklist

The packet must not contain real user data, a real SID, a real profile path, registry export content, Start menu or taskbar artifacts, offline image mount artifacts, installers, or network artifacts.

## Result Boundary

A complete mock packet may reach `authorization-review-ready`. It cannot reach `execute-ready`, `executed`, or `completed`.

All drill outputs keep:

- `AuthorizationApproved=false`
- `ExecutionApproved=false`
- `ExecuteReady=false`
- `trueExecution=false`
- `mutationCount=0`
- `userConfigurationConfirmed=false`

## Issue Boundary

This drill does not close Issue #18, does not create an Issue #18 completion summary, and does not claim that UX configuration has been restored.
