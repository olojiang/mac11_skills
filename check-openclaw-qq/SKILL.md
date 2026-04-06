---
name: check-openclaw-qq
description: End-to-end troubleshooting for OpenClaw QQ (OneBot/NapCat) message no-reply issues. Use when QQ channel appears configured/running but messages get no response, when openclaw/napcat services behave abnormally, when channel auto-restarts or reports ws/account errors, or when you need log-based root-cause isolation across service status, websocket link, inbound event direction, admin/mention filtering, and reply dispatch. Also use for requests mentioning check_openclaw_qq or check-openclaw-qq.
---

# Check OpenClaw QQ

## Overview

Use this skill to diagnose why OpenClaw QQ does not reply, with an evidence-first workflow and fixed command set.
Prioritize proving each pipeline stage in order: service health -> account mapping -> WS connectivity -> NapCat inbound -> OpenClaw event parse -> trigger filter -> reply dispatch.

## Workflow

1. Run quick snapshot:
`bash scripts/check_openclaw_qq_snapshot.sh 10`

2. Determine failure layer from logs, in strict order:
- `Service`:
`openclaw-gateway` and `napcat` must both be `active (running)`.
- `Account mapping`:
Identify active QQ self ID from OpenClaw logs, then verify matching NapCat file `.../config/onebot11_<self_id>.json` has enabled websocket server (host/port).
- `Transport`:
`ss` must show `127.0.0.1:3001` listen by NapCat and an established WS from OpenClaw to 3001.
- `Inbound`:
NapCat must show `接收 <-` for the test message (not only `发送 ->`).
- `Parse/Trigger`:
OpenClaw logs must show `Event type: message` and then trigger checks (`Checking admins`, `requireMention`, `fromId`).
- `Dispatch`:
OpenClaw must show `dispatching reply`/`Reply dispatched successfully`, and NapCat should show the outgoing send.

3. If needed, run targeted commands from [runbook](references/runbook.md) for the exact broken stage.

## Triage Rules

- Treat missing `接收 <-` in NapCat as upstream direction/session issue; do not debug LLM/model first.
- Treat `Login Error` with `serverErrorCode: 168` as QQ account risk-control issue; recovery must be done in latest mobile QQ first.
- Treat `3001` not listening + NapCat already receives messages as likely account-config mismatch (active account changed, wrong `onebot11_<qq>.json` edited).
- Treat present `接收 <-` + missing OpenClaw `Event type: message` as OneBot payload/parse issue.
- Treat present message event + no reply with `Not admin` or mention logs as policy/config issue.
- Treat present `Reply dispatched successfully` + user not seeing message as client-side visibility/session routing issue.

## Common Fixes

- Fix admin type mismatch in `~/.openclaw/openclaw.json`:
`"admins": [84501611]` (number array, not strings).
- Confirm QQ WS URL:
`"wsUrl": "ws://127.0.0.1:3001"`.
- If active login QQ changed, update the matching NapCat file:
`~/napcat/runtime/config/onebot11_<active_self_id>.json`
and ensure `websocketServers` includes enabled `127.0.0.1:3001`.
- If logs show repeated `wsUrl is required` / auto-restart loops, verify effective account config and restart gateway.
- If `napcat.service` restart is stuck in `deactivating` / `Failed to shutdown`, force kill and start service.
- Validate OneBot config in NapCat account file `.../config/onebot11_<qq>.json` (server enabled on 127.0.0.1:3001).

## Execution Notes

- Use a fresh test message and include absolute timestamps in findings.
- Keep conclusions evidence-based with exact log lines and times.
- After transport repair, wait at least one OpenClaw reconnect interval (~60s) before concluding still broken.
- If command execution is blocked by sandbox (`bwrap: loopback ...`), rerun with escalated permissions.
- Read detailed command matrix and diagnosis mapping in [runbook](references/runbook.md).

## Outputs

Always return:
1. Current health summary (services/channel/socket).
2. Exact failing stage in the pipeline.
3. Root cause hypothesis ranked by evidence.
4. Next corrective action with command(s) to verify fix.
