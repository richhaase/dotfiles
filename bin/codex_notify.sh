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

context_path=$(jq -r '.workspace // .working_directory // .cwd // ""' <<<"$notification_json")
if [[ -z $context_path || $context_path == "null" ]]; then
  context_path="$PWD"
fi
if [[ ${context_path:0:1} == "~" ]]; then
  context_path="${context_path/#\~/$HOME}"
fi
if [[ $context_path != /* ]]; then
  context_path="$PWD/${context_path#./}"
fi
if [[ -d $context_path ]]; then
  context_path="$(cd "$context_path" && pwd -P)"
else
  context_path="$PWD"
fi

title_path="$context_path"
if command -v git >/dev/null 2>&1; then
  git_root=$(git -C "$context_path" rev-parse --show-toplevel 2>/dev/null || true)
  if [[ -n ${git_root:-} ]]; then
    title_path="$git_root"
  fi
fi
display_path="${title_path/#$HOME/\~}"
title="Codex: $display_path"

case "$notification_type" in
  agent-turn-complete)
    assistant_message=$(jq -r '."last-assistant-message" // ""' <<<"$notification_json")
    if [[ -z $assistant_message || $assistant_message == "null" ]]; then
      message=$(jq -r '.input_messages // [] | map(tostring) | join(" ")' <<<"$notification_json")
    else
      message="$assistant_message"
    fi
    ;;
  *)
    message=$(jq -c '.' <<<"$notification_json")
    ;;
esac

if [[ -z $message ]]; then
  message="Notification received."
fi

message=${message//$'\r'/ }
message=${message//$'\n'/ }
max_chars=250
if (( ${#message} > max_chars )); then
  message="${message:0:max_chars}..."
fi

terminal-notifier \
  -message "$message" \
  -title "$title" \
  -ignoreDnD \
  -sound Glass
