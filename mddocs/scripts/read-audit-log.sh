#!/usr/bin/env bash
# Pretty-print the current session's egress audit log.
# Usage: read-audit-log.sh [date]   (date format: YYYY-MM-DD; default: today)
set -euo pipefail

DATE="${1:-$(date +%Y-%m-%d)}"
LOG="$HOME/.agentic/audit/session-${DATE}.jsonl"

if [[ ! -f "$LOG" ]]; then
  echo "No audit log for ${DATE}: ${LOG}"
  exit 0
fi

echo "=== Egress audit log: ${DATE} ==="
echo ""

while IFS= read -r line; do
  tool=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool','?'))" 2>/dev/null)
  ts=$(echo "$line"   | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('ts','?')[:19])" 2>/dev/null)

  case "$tool" in
    Bash)
      cmd=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('command','?'))" 2>/dev/null)
      code=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('exit_code','?'))" 2>/dev/null)
      echo "[$ts] BASH  exit=${code}  ${cmd}"
      ;;
    WebFetch)
      url=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('url','?'))" 2>/dev/null)
      allowed=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('web_allowed','?'))" 2>/dev/null)
      echo "[$ts] FETCH web_allowed=${allowed}  ${url}"
      ;;
    WebSearch)
      query=$(echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('query','?'))" 2>/dev/null)
      echo "[$ts] SEARCH  ${query}"
      ;;
    *)
      echo "[$ts] ${tool}  ${line}"
      ;;
  esac
done < "$LOG"

echo ""
echo "$(wc -l < "$LOG") entries in ${LOG}"
