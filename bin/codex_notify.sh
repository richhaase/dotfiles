#!/usr/bin/env bash
# Usage: codex_notify.sh <NOTIFICATION_JSON>

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: codex_notify.sh <NOTIFICATION_JSON>

Parse Codex event JSON (from the CLI) and forward a desktop
notification via terminal-notifier.
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "codex_notify.sh: jq is required" >&2
  exit 1
fi

if ! command -v terminal-notifier >/dev/null 2>&1; then
  echo "codex_notify.sh: terminal-notifier is required" >&2
  exit 1
fi

notification_json=$1

if ! jq empty <<<"$notification_json" >/dev/null 2>&1; then
  echo "codex_notify.sh: invalid JSON payload" >&2
  exit 1
fi

notification_type=$(jq -r '.type // ""' <<<"$notification_json")

case "$notification_type" in
  agent-turn-complete)
    assistant_message=$(jq -r '."last-assistant-message" // ""' <<<"$notification_json")
    if [[ -n $assistant_message ]]; then
      title="Codex: $assistant_message"
    else
      title="Codex: Turn Complete!"
    fi
    message=$(jq -r '.input_messages // [] | map(tostring) | join(" ")' <<<"$notification_json")
    ;;
  *)
    title="Codex: Unknown Event"
    message=$(jq -c '.' <<<"$notification_json")
    ;;
esac

if [[ -z $message ]]; then
  message="Notification received."
fi

terminal-notifier \
  -title "$title" \
  -message "$message" \
  -ignoreDnD \
  -sound Glass
