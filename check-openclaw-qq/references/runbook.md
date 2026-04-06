# OpenClaw QQ Troubleshooting Runbook

## 1) Fast Command Set

```bash
# Full snapshot (recommended first step)
bash scripts/check_openclaw_qq_snapshot.sh 10

# Service status only
systemctl --user status openclaw-gateway.service --no-pager
systemctl status napcat.service --no-pager

# Channel runtime view
openclaw channels status --json

# Message direction and reply pipeline
journalctl -u napcat.service --since "10 min ago" --no-pager | rg "接收 <-|发送 ->"
journalctl --user -u openclaw-gateway.service --since "10 min ago" --no-pager | rg "Event type: message|Not admin|dispatching reply|Reply dispatched|Error dispatching"

# Account/risk control quick checks
journalctl -u napcat.service --since "30 min ago" --no-pager | rg "Login Error|ErrInfo|serverErrorCode|二维码解码URL|授权登录"
journalctl --user -u openclaw-gateway.service --since "30 min ago" --no-pager | rg "Logged in as|Self ID|Connected to OneBot|ECONNREFUSED"
ls -1 ~/napcat/runtime/config/onebot11_*.json
```

## 2) Pipeline Decision Tree

1. If service inactive:
   restart service first, then retest.
2. If service active but no `3001` listener or no established WS:
   first check account mapping: active QQ self ID must match edited `onebot11_<qq>.json`; then fix transport path (`wsUrl`, NapCat OneBot server enable, local firewall/policy).
3. If WS connected but NapCat has only `发送 ->` and no `接收 <-`:
   inbound message never reached bot account; verify sender/session direction.
4. If NapCat has `接收 <-` but OpenClaw lacks `Event type: message`:
   investigate payload parse/format compatibility and channel parser.
5. If OpenClaw has `Event type: message` but no reply:
   check `Not admin`, mention/trigger policy, blocked user settings.
6. If OpenClaw shows `Reply dispatched successfully` but user sees nothing:
   verify QQ client conversation routing, message visibility, and account context.
7. If transport was just repaired:
   wait one reconnect cycle (~60s) before declaring failure; confirm with both `ss` and OpenClaw reconnect logs.

## 3) Known Root Causes and Fix Patterns

- `admins` type wrong:
  ensure number array in `~/.openclaw/openclaw.json`, for example:
  `"admins": [84501611]`
- missing/invalid `wsUrl`:
  ensure:
  `"wsUrl": "ws://127.0.0.1:3001"`
- repeated channel restart with `wsUrl is required`:
  validate effective account resolution and channel startup contract.
- false test direction:
  if logs show bot `发送 ->` only, user may be sending from wrong side.
- QQ risk-control block:
  if logs include `serverErrorCode: 168`, recover account in latest mobile QQ first, then restart NapCat and retest.
- account drift/config mismatch:
  active login account can change after re-login; if you edited `onebot11_A.json` but active account is `B`, `3001` may stay down even though NapCat is receiving messages.
  always verify active self ID from logs and edit `onebot11_<active_self_id>.json`.
- restart stuck (`deactivating`, `Failed to shutdown`):
  run:
  `systemctl kill -s SIGKILL napcat.service && systemctl start napcat.service`

## 4) Account Mapping Recovery

1. Identify active account:
`journalctl --user -u openclaw-gateway.service --since "30 min ago" --no-pager | rg "Logged in as|Self ID"`
2. Verify matching OneBot file:
`sed -n '1,200p' ~/napcat/runtime/config/onebot11_<active_self_id>.json`
3. Ensure websocket server enabled:
`host=127.0.0.1`, `port=3001`, `enable=true`.
4. Restart NapCat and verify:
`systemctl restart napcat.service`
`ss -ltnp | rg ':3001|:18789'`
`ss -tnp | rg ':3001'`

## 5) Evidence Format for Reports

Always include:

1. Absolute timestamps.
2. Stage verdict: `service | transport | inbound | parse | dispatch`.
3. One key log line per stage.
4. Exact next command to confirm fix.
