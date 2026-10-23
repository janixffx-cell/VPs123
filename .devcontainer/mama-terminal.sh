#!/usr/bin/env bash
# Mama VPS web terminal: runs ttyd (xterm.js shell) on port 7681 inside the Codespace.
# The forwarded port stays PRIVATE: GitHub only lets the Codespace owner open it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.mama-vps"
BIN=/usr/bin/ttyd
LOG="$ROOT/.mama-vps/terminal.log"
install() {
  [ -x "$BIN" ] && command -v tmux >/dev/null && return 0
  sudo apt-get update && sudo apt-get install -y ttyd tmux ca-certificates
  "$BIN" --version
}
running() { pgrep -f "ttyd .*-p 7681" >/dev/null 2>&1; }
start() {
  install || { echo "[mama-vps] ttyd install failed" | tee -a "$LOG"; return 1; }
  pkill -f "ttyd .*-p 7681" 2>/dev/null || true
  cd "$ROOT"
  # GitHub's CLI authenticates as the Codespace user. Never expose an unauthenticated shell publicly.
  if [ -n "${CODESPACE_NAME:-}" ]; then
    command -v gh >/dev/null || { echo '[mama-vps] GitHub CLI missing; refusing to expose shell.' | tee -a "$LOG"; return 1; }
    gh codespace ports visibility 7681:private -c "$CODESPACE_NAME" >>"$LOG" 2>&1 || { echo '[mama-vps] Cannot enforce private port; refusing to start.' | tee -a "$LOG"; return 1; }
  fi
  # setsid + nohup so the terminal survives after the lifecycle command returns.
  setsid nohup "$BIN" -W -p 7681 -P 30 -t reconnect=10 -t fontSize=14 -t 'theme={"background":"#030805","foreground":"#33ff66","cursor":"#33ff66"}' tmux new-session -A -s mama-shell >>"$LOG" 2>&1 < /dev/null &
  disown || true
  sleep 1
  running && echo "[mama-vps] terminal listening on 7681" || { echo "[mama-vps] ttyd failed to start, see $LOG"; return 1; }
}
ensure() { running || start; }
"${1:-start}"
