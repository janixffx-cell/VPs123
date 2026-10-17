#!/usr/bin/env bash
# Mama VPS web terminal: runs ttyd (xterm.js shell) on port 7681 inside the Codespace.
# The forwarded port stays PRIVATE: GitHub only lets the Codespace owner open it.
set -uo pipefail
VER=1.7.7
BIN=/usr/local/bin/ttyd
LOG=/tmp/mama-terminal.log
install() {
  [ -x "$BIN" ] && return 0
  case "$(uname -m)" in x86_64) a=x86_64;; aarch64|arm64) a=aarch64;; *) echo "unsupported arch"; return 1;; esac
  sudo curl -fsSL --retry 3 "https://github.com/tsl0922/ttyd/releases/download/${VER}/ttyd.${a}" -o "$BIN" && sudo chmod +x "$BIN"
}
running() { pgrep -f "ttyd .*-p 7681" >/dev/null 2>&1; }
start() {
  install || { echo "[mama-vps] ttyd install failed" | tee -a "$LOG"; return 1; }
  pkill -f "ttyd .*-p 7681" 2>/dev/null || true
  cd "${CODESPACE_VSCODE_FOLDER:-$HOME}" 2>/dev/null || cd "$HOME"
  # setsid + nohup so the terminal survives after the lifecycle command returns.
  setsid nohup "$BIN" -W -p 7681 -P 30 -t fontSize=14 -t 'theme={"background":"#05050a"}' bash -l >>"$LOG" 2>&1 < /dev/null &
  disown || true
  sleep 1
  running && echo "[mama-vps] terminal listening on 7681" || { echo "[mama-vps] ttyd failed to start, see $LOG"; return 1; }
}
ensure() { running || start; }
"${1:-start}"
