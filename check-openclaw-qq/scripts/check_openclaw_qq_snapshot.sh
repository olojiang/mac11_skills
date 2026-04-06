#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash check_openclaw_qq_snapshot.sh               # default 10 min
#   bash check_openclaw_qq_snapshot.sh 20            # last 20 min
#   bash check_openclaw_qq_snapshot.sh "2 min ago"   # custom journalctl --since expression

SINCE_INPUT="${1:-10}"
if [[ "${SINCE_INPUT}" =~ ^[0-9]+$ ]]; then
  SINCE_EXPR="${SINCE_INPUT} min ago"
else
  SINCE_EXPR="${SINCE_INPUT}"
fi

if command -v rg >/dev/null 2>&1; then
  FILTER_BIN="rg"
else
  FILTER_BIN="grep -E"
fi

NAPCAT_CONFIG_DIR="${HOME}/napcat/runtime/config"

print_section() {
  echo
  echo "===== $1 ====="
}

print_section "Now"
date "+%F %T %Z"
echo "since: ${SINCE_EXPR}"

print_section "Service Active"
{
  echo -n "openclaw-gateway: "
  systemctl --user is-active openclaw-gateway.service
} || true
{
  echo -n "napcat: "
  systemctl is-active napcat.service
} || true

print_section "Service Status (Short)"
systemctl --user status openclaw-gateway.service --no-pager | tail -n 20 || true
systemctl status napcat.service --no-pager | tail -n 20 || true

print_section "Channel Status JSON"
openclaw channels status --json || true

print_section "Socket Check"
ss -ltnp | ${FILTER_BIN} ':3001|:18789' || true
ss -tnp | ${FILTER_BIN} '3001|18789' || true

print_section "NapCat Login/Error Signals"
journalctl -u napcat.service --since "${SINCE_EXPR}" --no-pager | ${FILTER_BIN} '登录成功|Login Error|ErrInfo|serverErrorCode|二维码解码URL|授权登录|风险' || true

print_section "NapCat OneBot Config Summary"
if compgen -G "${NAPCAT_CONFIG_DIR}/onebot11_*.json" >/dev/null 2>&1; then
  for cfg in "${NAPCAT_CONFIG_DIR}"/onebot11_*.json; do
    echo "- $(basename "${cfg}")"
    if command -v jq >/dev/null 2>&1; then
      jq -r '.network.websocketServers // [] | if length == 0 then "  websocketServers: []" else .[] | "  name=\(.name // "null") enable=\(.enable // "null") host=\(.host // "null") port=\(.port // "null")" end' "${cfg}" 2>/dev/null || true
    else
      sed -n '1,120p' "${cfg}" | ${FILTER_BIN} 'websocketServers|name|enable|host|port' || true
    fi
  done
else
  echo "No onebot11_*.json found under ${NAPCAT_CONFIG_DIR}"
fi

print_section "Account Mapping Check"
ACTIVE_SELF_ID="$(journalctl --user -u openclaw-gateway.service --since "${SINCE_EXPR}" --no-pager | sed -n 's/.*Self ID: \([0-9][0-9]*\).*/\1/p' | tail -n 1)"
if [[ -z "${ACTIVE_SELF_ID}" ]]; then
  ACTIVE_SELF_ID="$(journalctl --user -u openclaw-gateway.service --since "12 hours ago" --no-pager | sed -n 's/.*Logged in as: .* (\([0-9][0-9]*\)).*/\1/p' | tail -n 1)"
fi

if [[ -n "${ACTIVE_SELF_ID}" ]]; then
  ACTIVE_CFG="${NAPCAT_CONFIG_DIR}/onebot11_${ACTIVE_SELF_ID}.json"
  echo "OpenClaw active Self ID: ${ACTIVE_SELF_ID}"
  if [[ -f "${ACTIVE_CFG}" ]]; then
    echo "Matched OneBot config: ${ACTIVE_CFG}"
    if command -v jq >/dev/null 2>&1; then
      WS_COUNT="$(jq '.network.websocketServers // [] | length' "${ACTIVE_CFG}" 2>/dev/null || echo "unknown")"
      echo "websocketServers length: ${WS_COUNT}"
      jq -r '.network.websocketServers // [] | .[]? | "name=\(.name // "null") enable=\(.enable // "null") host=\(.host // "null") port=\(.port // "null")"' "${ACTIVE_CFG}" 2>/dev/null || true
    else
      sed -n '1,120p' "${ACTIVE_CFG}" | ${FILTER_BIN} 'websocketServers|name|enable|host|port' || true
    fi
  else
    echo "Matched OneBot config missing: ${ACTIVE_CFG}"
  fi
else
  echo "Could not infer active Self ID from recent OpenClaw logs."
fi

print_section "NapCat Direction Logs"
journalctl -u napcat.service --since "${SINCE_EXPR}" --no-pager | ${FILTER_BIN} '接收 <-|发送 ->|输入状态' || true

print_section "OpenClaw QQ Pipeline Logs"
journalctl --user -u openclaw-gateway.service --since "${SINCE_EXPR}" --no-pager | ${FILTER_BIN} 'Event type: message|Not admin|requireMention|dispatching reply|Reply dispatched|Error dispatching|Connected account|Connected to OneBot server|wsUrl is required|auto-restart attempt|Critical error in message handler' || true
