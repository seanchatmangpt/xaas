#!/usr/bin/env bash
#
# Installs (or removes) the GLM failover dispatcher as a per-user launchd agent.
#
#   scripts/install-glm-failover-launchd.sh print       render plist to stdout (no side effects)
#   scripts/install-glm-failover-launchd.sh install     write plist + bootstrap
#   scripts/install-glm-failover-launchd.sh uninstall   bootout + remove plist
#   scripts/install-glm-failover-launchd.sh status      show launchd state + heartbeat age
#
# Env: ZCODE_CLI_DIR, POLL_INTERVAL, DISPATCH_TIMEOUT, STATE_DIR (see dispatcher header).

set -eu

LABEL="dev.xaas.glm-failover-dispatcher"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
XAAS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISPATCHER="$XAAS_DIR/scripts/xaas-glm-failover-dispatcher.sh"
STATE_DIR="${STATE_DIR:-$HOME/.zcode/failover}"
ZCODE_CLI_DIR="${ZCODE_CLI_DIR:-/Users/sac/dev/zcode-cli}"
POLL_INTERVAL="${POLL_INTERVAL:-30}"
DISPATCH_TIMEOUT="${DISPATCH_TIMEOUT:-840}"
DOMAIN="gui/$(id -u)"

render_plist() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${DISPATCHER}</string>
    <string>--interval</string>
    <string>${POLL_INTERVAL}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>ZCODE_CLI_DIR</key><string>${ZCODE_CLI_DIR}</string>
    <key>DISPATCH_TIMEOUT</key><string>${DISPATCH_TIMEOUT}</string>
    <key>STATE_DIR</key><string>${STATE_DIR}</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>15</integer>
  <key>StandardOutPath</key><string>${STATE_DIR}/dispatcher.out.log</string>
  <key>StandardErrorPath</key><string>${STATE_DIR}/dispatcher.err.log</string>
</dict>
</plist>
EOF
}

case "${1:-}" in
  print)
    render_plist
    ;;
  install)
    mkdir -p "$STATE_DIR" "$HOME/Library/LaunchAgents"
    render_plist > "$PLIST"
    plutil -lint "$PLIST"
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    launchctl bootstrap "$DOMAIN" "$PLIST"
    launchctl kickstart -k "$DOMAIN/$LABEL"
    echo "installed ${LABEL} (plist: ${PLIST})"
    ;;
  uninstall)
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    echo "removed ${LABEL}"
    ;;
  status)
    launchctl print "$DOMAIN/$LABEL" 2>&1 | grep -E "state|pid|last exit" || echo "not loaded"
    if [ -f "$STATE_DIR/heartbeat" ]; then
      echo "heartbeat_age_seconds=$(( $(date +%s) - $(cat "$STATE_DIR/heartbeat") ))"
    else
      echo "heartbeat: none"
    fi
    [ -f "$STATE_DIR/alert" ] && echo "ALERT: $(cat "$STATE_DIR/alert")" || true
    ;;
  *)
    echo "Usage: $0 {print|install|uninstall|status}" >&2
    exit 2
    ;;
esac
